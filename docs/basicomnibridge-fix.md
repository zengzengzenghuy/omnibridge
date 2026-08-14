# Omnibridge — WETH Router Griefing Fix

Source: [`contracts/upgradeable_contracts/BasicOmnibridge.sol`](../contracts/upgradeable_contracts/BasicOmnibridge.sol) (`_receiverCallback`)

> A permissionless relayer could choose a gas limit that lets a WETH claim settle while starving the
> unwrap callback, leaving WETH stranded in [`WETHOmnibridgeRouter`](../contracts/helpers/WETHOmnibridgeRouter.sol)
> and the recipient with nothing. Fixed by detecting callback gas starvation via the EIP-150 63/64 rule.

## Affected path

A user bridging WETH back to Ethereum and asking for native ETH sets the message recipient to
`WETHOmnibridgeRouter`, with their own address as the 20-byte payload. HomeOmnibridge therefore emits
`handleNativeTokensAndCall(WETH, router, value, abi.encodePacked(recipient))`.

```
ForeignAMB.executeSignatures / safeExecuteSignaturesWithGasLimit
  └─ MessageProcessor.processMessage → executor.call.gas(_gas)(data)
       └─ ForeignOmnibridge.handleNativeTokensAndCall           [onlyMediator]
            ├─ _handleTokens → _releaseTokens                    ← WETH transferred to the ROUTER
            └─ _receiverCallback → router.onTokenBridged(...)    ← unwrap + forward ETH to the user
                 ├─ WETH.withdraw(value)
                 └─ AddressHelper.safeSendValue(recipient, value)
```

The two halves settle in different frames, and the second one was optional.

## Cause

`_receiverCallback` invoked the callback with a bare low-level call and discarded the result:

```solidity
if (Address.isContract(_recipient)) {
    _recipient.call(abi.encodeWithSelector(IERC20Receiver.onTokenBridged.selector, _token, _value, _data));
}
```

Three properties combine into an exploitable grief:

1. **Tokens move before the callback runs.** `_handleTokens` has already transferred WETH to the
   router by the time `onTokenBridged` is invoked, so a failed callback leaves a half-completed claim rather than no claim.
2. **The result is discarded**, so an out-of-gas callback is indistinguishable from success. The outer
   `handleNativeTokensAndCall` returns normally and the AMB marks the message executed.
3. **The caller picks the gas.** `executeSignatures` and `safeExecuteSignaturesWith*` are permissionless — the signatures
   authorise the claim, not the sender — so _anyone_ can relay a validly signed message with a gas
   limit of their choosing. `safeExecuteSignaturesWithGasLimit(data, sigs, _gas)` takes `_gas`
   directly; plain `executeSignatures` takes it from the message header.

EIP-150 gives the callback at most 63/64 of the gas remaining when it is invoked, so a relayer who
forwards enough for `_handleTokens` but not for `_handleTokens` + `onTokenBridged` lands in a window
where the claim settles to the router and the unwrap silently fails.

### Measured gas bands

100 WETH claim to a fresh (zero-balance) recipient, mainnet fork at ~block 25.72M, against the
deployed implementation `0x8eB3b7D8498a6716904577b2579e1c313d48E347`:

| gas forwarded to the mediator | outcome                                                         |
| ----------------------------- | --------------------------------------------------------------- |
| < 87,000                      | mediator itself runs out of gas → whole call fails              |
| **87,000 – 131,000**          | **grief** — WETH stranded in the router, recipient gets nothing |
| ≥ 131,250                     | correct: router unwraps and forwards 100 ETH                    |

## Impact

WETH equal to the claim amount is left in the router, and the recipient receives nothing. The router
holds no per-user accounting, so the funds are not attributable or withdrawable by the intended owner.

Severity depends on the relay entry point:

| entry point                             | attacker controls the gas via | result before the fix                                             |
| --------------------------------------- | ----------------------------- | ----------------------------------------------------------------- |
| `safeExecuteSignaturesWithGasLimit`     | the `_gas` argument           | WETH stranded; message consumed                                   |
| `executeSignatures`                     | the message header `gasLimit` | WETH stranded **and** the AMB records `messageCallStatus == true` |
| `safeExecuteSignaturesWithAutoGasLimit` | —                             | **not exploitable** (see below)                                   |

The second row is the worse one. `FailedMessagesProcessor.requestFailedMessageFix` requires
`!bridge.messageCallStatus(_messageId)`, so a message recorded as successful cannot be rolled back on
the Home side. There is no recovery path.

`safeExecuteSignaturesWithAutoGasLimit` is structurally immune, before and after the fix. It forwards
`0xffffffff`, so EIP-150 gives the mediator 63/64 of the remaining gas and the AMB retains only 1/64.
For the AMB to have enough left to finish its own bookkeeping, the mediator must have received about
63× that — always far above the grief band. The outcome is therefore binary: the whole transaction
reverts, or the claim completes correctly. Confirmed by sweeping the transaction gas budget from
200,000 to 3,000,000: zero grief windows, first success at 275,000.

## Fix

```solidity
function _receiverCallback(
  address _recipient,
  address _token,
  uint256 _value,
  bytes memory _data
) internal {
  if (Address.isContract(_recipient)) {
    uint256 gasBefore = gasleft();
    (bool success, ) =
      _recipient.call(abi.encodeWithSelector(IERC20Receiver.onTokenBridged.selector, _token, _value, _data));
    // EIP-150 caps the callee at 63/64 of gasBefore, so an out-of-gas callee leaves ~1/64.
    // More than that means it reverted for its own reasons — keep the existing tolerance.
    if (!success) {
      require(gasleft() > gasBefore / 63, 'callback out of gas');
    }
  }
}

```

The check does not ask _"was there enough gas"_ — it asks _"did the callee burn everything it was
given"_, which is the EIP-150 signature of starvation:

- a callee that runs out consumes the full 63/64 it received, leaving ≈ `gasBefore / 64`, which is
  strictly less than `gasBefore / 63` → **revert**;
- a callee that reverts on its own returns the unspent remainder, leaving far more → **tolerated**,
  exactly as before.

### Why the bound is `/63` and not `/64`

A non-starved callee is only guaranteed to leave _more_ than `gasBefore / 64` — the amount EIP-150
withheld from it — and one that reverts on its own after burning nearly everything it was given
leaves just barely more. So the two verdicts sit this close together:

```
     gasBefore/64          gasBefore/63                                gasBefore
 ─────────┼───────────────────┼──────────────────────────────────────────────
          ^ out-of-gas lands  ^ threshold
          └──── reject ───────┴──────────────── accept ──────────────────────
```

A `gasleft() > gasBefore / 64` threshold would be decided by rounding noise — the two cases can
differ by a single gas unit. `/63` inserts a margin of `gasBefore / (63 * 64)`, about **1.5% of the
forwarded gas**, between them.

The cost is a false positive: a callee that deliberately burns its whole allowance and then reverts
(a gas-burning loop, or an `assert`/invalid-opcode revert) is rejected alongside a genuine
out-of-gas. From inside `_receiverCallback` the two are indistinguishable, and rejecting is the safe
direction — the message stays replayable, or recoverable via `requestFailedMessageFix`, instead of
settling with the tokens stranded in the receiver.

Placing it in `BasicOmnibridge` covers both `ForeignOmnibridge` and `HomeOmnibridge`, and every
`*AndCall` entry point, in one place.

### Behaviour after the fix

| entry point              | starved relay                                                                                      | honest relay     |
| ------------------------ | -------------------------------------------------------------------------------------------------- | ---------------- |
| `safeExecuteSignatures*` | whole transaction reverts; message stays replayable                                                | settles normally |
| `executeSignatures`      | recorded as a **failed** message; `requestFailedMessageFix` rolls the tokens back on the Home side | settles normally |

Either way the user's funds survive.

# Acknowledgement

This bug is found by [heisenberg92](https://immunefi.com/profile/heisenberg92/) for the [Gnosis Chain's Immunefi Bug Bounty](https://docs.gnosischain.com/about/specs/bug-bounty).
