---
sponsor: "Superposition"
slug: "2024-08-superposition"
date: "2024-10-18"
title: "Superposition"
findings: "https://github.com/code-423n4/2024-08-superposition-findings/issues"
contest: 428
---

# Overview

## About C4

Code4rena (C4) is an open organization consisting of security researchers, auditors, developers, and individuals with domain expertise in smart contracts.

A C4 audit is an event in which community participants, referred to as Wardens, review, audit, or analyze smart contract logic in exchange for a bounty provided by sponsoring projects.

During the audit outlined in this document, C4 conducted an analysis of the Superposition smart contract system written in Solidity and Rust. The audit took place between August 23 — September 13, 2024.

## Wardens

51 Wardens contributed reports to Superposition:

  1. [DadeKuma](https://code4rena.com/@DadeKuma)
  2. [oakcobalt](https://code4rena.com/@oakcobalt)
  3. [Testerbot](https://code4rena.com/@Testerbot)
  4. [prapandey031](https://code4rena.com/@prapandey031)
  5. [zhaojohnson](https://code4rena.com/@zhaojohnson)
  6. [wasm\_it](https://code4rena.com/@wasm_it) ([0xrex](https://code4rena.com/@0xrex) and [rustguy](https://code4rena.com/@rustguy))
  7. [adeolu](https://code4rena.com/@adeolu)
  8. [13u9](https://code4rena.com/@13u9)
  9. [ZanyBonzy](https://code4rena.com/@ZanyBonzy)
  10. [Tricko](https://code4rena.com/@Tricko)
  11. [SBSecurity](https://code4rena.com/@SBSecurity) ([Slavcheww](https://code4rena.com/@Slavcheww) and [Blckhv](https://code4rena.com/@Blckhv))
  12. [shaflow2](https://code4rena.com/@shaflow2)
  13. [Q7](https://code4rena.com/@Q7)
  14. [Silvermist](https://code4rena.com/@Silvermist)
  15. [mashbust](https://code4rena.com/@mashbust) ([gulDozer](https://code4rena.com/@gulDozer), [usmanatique](https://code4rena.com/@usmanatique), [abdulsamijay](https://code4rena.com/@abdulsamijay) and [0xabdullah0](https://code4rena.com/@0xabdullah0))
  16. [eta](https://code4rena.com/@eta)
  17. [d4r3d3v1l](https://code4rena.com/@d4r3d3v1l)
  18. [peanuts](https://code4rena.com/@peanuts)
  19. [aldarion](https://code4rena.com/@aldarion)
  20. [pipidu83](https://code4rena.com/@pipidu83)
  21. [0xhashiman](https://code4rena.com/@0xhashiman)
  22. [Nikki](https://code4rena.com/@Nikki)
  23. [nnez](https://code4rena.com/@nnez)
  24. [OMEN](https://code4rena.com/@OMEN)
  25. [nslavchev](https://code4rena.com/@nslavchev)
  26. [Japy69](https://code4rena.com/@Japy69)
  27. [devival](https://code4rena.com/@devival)
  28. [SpicyMeatball](https://code4rena.com/@SpicyMeatball)
  29. [IzuMan](https://code4rena.com/@IzuMan)
  30. [Shubham](https://code4rena.com/@Shubham)
  31. [ABAIKUNANBAEV](https://code4rena.com/@ABAIKUNANBAEV)
  32. [Rhaydden](https://code4rena.com/@Rhaydden)
  33. [rare\_one](https://code4rena.com/@rare_one)
  34. [debo](https://code4rena.com/@debo)
  35. [Tigerfrake](https://code4rena.com/@Tigerfrake)
  36. [0xAleko](https://code4rena.com/@0xAleko)
  37. [0xastronatey](https://code4rena.com/@0xastronatey)
  38. [Agontuk](https://code4rena.com/@Agontuk)
  39. [swapnaliss](https://code4rena.com/@swapnaliss)
  40. [Sparrow](https://code4rena.com/@Sparrow)
  41. [NexusAudits](https://code4rena.com/@NexusAudits) ([cheatc0d3](https://code4rena.com/@cheatc0d3) and [Zanna](https://code4rena.com/@Zanna))
  42. [Bauchibred](https://code4rena.com/@Bauchibred)
  43. [Decap](https://code4rena.com/@Decap)
  44. [dreamcoder](https://code4rena.com/@dreamcoder)
  45. [zhaojie](https://code4rena.com/@zhaojie)

This audit was judged by [0xsomeone](https://code4rena.com/@0xsomeone).

Final report assembled by [thebrittfactor](https://twitter.com/brittfactorC4).

# Summary

The C4 analysis yielded an aggregated total of 19 unique vulnerabilities. Of these vulnerabilities, 7 received a risk rating in the category of HIGH severity and 12 received a risk rating in the category of MEDIUM severity.

Additionally, C4 analysis included 16 reports detailing issues with a risk rating of LOW severity or non-critical.

All of the issues presented here are linked back to their original finding.

# Scope

The code under review can be found within the [C4 Superposition repository](https://github.com/code-423n4/2024-08-superposition), and is composed of 26 smart contracts written in the Solidity programming language and includes 5248 lines of Solidity code.

# Severity Criteria

C4 assesses the severity of disclosed vulnerabilities based on three primary risk categories: high, medium, and low/non-critical.

High-level considerations for vulnerabilities span the following key areas when conducting assessments:

- Malicious Input Handling
- Escalation of privileges
- Arithmetic
- Gas use

For more information regarding the severity criteria referenced throughout the submission review process, please refer to the documentation provided on [the C4 website](https://code4rena.com), specifically our section on [Severity Categorization](https://docs.code4rena.com/awarding/judging-criteria/severity-categorization).

# High Risk Findings (7)
## [[H-01] `update_emergency_council_7_D_0_C_1_C_58()` updates nft manager instead of emergency council](https://github.com/code-423n4/2024-08-superposition-findings/issues/162)
*Submitted by [ABAIKUNANBAEV](https://github.com/code-423n4/2024-08-superposition-findings/issues/162), also found by [Q7](https://github.com/code-423n4/2024-08-superposition-findings/issues/153), [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/145), [ZanyBonzy](https://github.com/code-423n4/2024-08-superposition-findings/issues/137), [Rhaydden](https://github.com/code-423n4/2024-08-superposition-findings/issues/134), [Nikki](https://github.com/code-423n4/2024-08-superposition-findings/issues/132), [nslavchev](https://github.com/code-423n4/2024-08-superposition-findings/issues/128), [Testerbot](https://github.com/code-423n4/2024-08-superposition-findings/issues/103), [eta](https://github.com/code-423n4/2024-08-superposition-findings/issues/89), [d4r3d3v1l](https://github.com/code-423n4/2024-08-superposition-findings/issues/78), [prapandey031](https://github.com/code-423n4/2024-08-superposition-findings/issues/76), [zhaojohnson](https://github.com/code-423n4/2024-08-superposition-findings/issues/64), [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/23), [wasm\_it](https://github.com/code-423n4/2024-08-superposition-findings/issues/11), and [shaflow2](https://github.com/code-423n4/2024-08-superposition-findings/issues/7)*

Inside of `lib.rs`, there is a function `update_emergency_council_7_D_0_C_1_C_58()` that is needed to update the emergency council that can disable the pools. However, in the current implementation, `nft_manager` is updated instead.

### Proof of Concept

This is the current functionality of `update_emergency_council_7_D_0_C_1_C_58()`:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/lib.rs#L1111-1124>

```
    pub fn update_emergency_council_7_D_0_C_1_C_58(
            &mut self,
            manager: Address,
        ) -> Result<(), Revert> {
            assert_eq_or!(
                msg::sender(),
                self.seawater_admin.get(),
                Error::SeawaterAdminOnly
            );

            self.nft_manager.set(manager);

            Ok(())
        }
```

As you can see, the function updates `nft_manager` contract instead of `emergency_council` that is needed to be updated. Above this function there is another function that updates `nft_manager`:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/lib.rs#L1097-1107>

```
  pub fn update_nft_manager_9_B_D_F_41_F_6(&mut self, manager: Address) -> Result<(), Revert> {
        assert_eq_or!(
            msg::sender(),
            self.seawater_admin.get(),
            Error::SeawaterAdminOnly
        );

        self.nft_manager.set(manager);

        Ok(())
    }
```

As you can see here, in both of the functions `nft_manager` is updated which is an unexpected behavior and the contract cannot update the `emergency_council` that handles emergency situations:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/lib.rs#L117-118>

```
     // address that's able to activate and disable emergency mode functionality
        emergency_council: StorageAddress,
```

### Recommended Mitigation Steps

Change `update_emergency_council_7_D_0_C_1_C_58()` to update `emergency_council`.

**[af-afk (Superposition) confirmed via duplicate issue #64](https://github.com/code-423n4/2024-08-superposition-findings/issues/64#event-14265172686)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/162#issuecomment-2369609895):**
 > The Warden and its duplicates have correctly identified that the mechanism exposed for updating the `emergency_council` will incorrectly update the `nft_manager` instead. 
> 
> I initially wished to retain a medium risk severity rating for this vulnerability due to how the `emergency_council` is configured during the contract's initialization and its value changing being considered a rare event; however, a different highly sensitive variable is altered instead incorrectly (`nft_manager`) which would have significant consequences to the system temporarily.
> 
> Based on the above, I believe that a high-risk rating is appropriate due to the unexpected effects invocation of the function would result in.

***

## [[H-02] Unrevoked approvals allow NFT recovery by previous owner](https://github.com/code-423n4/2024-08-superposition-findings/issues/160)
*Submitted by [Japy69](https://github.com/code-423n4/2024-08-superposition-findings/issues/160), also found by [zhaojohnson](https://github.com/code-423n4/2024-08-superposition-findings/issues/156), [ZanyBonzy](https://github.com/code-423n4/2024-08-superposition-findings/issues/141), [Testerbot](https://github.com/code-423n4/2024-08-superposition-findings/issues/104), [IzuMan](https://github.com/code-423n4/2024-08-superposition-findings/issues/100), [Shubham](https://github.com/code-423n4/2024-08-superposition-findings/issues/93), [SBSecurity](https://github.com/code-423n4/2024-08-superposition-findings/issues/74), [Nikki](https://github.com/code-423n4/2024-08-superposition-findings/issues/56), [SpicyMeatball](https://github.com/code-423n4/2024-08-superposition-findings/issues/27), and [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/25)*

The vulnerability arises from the fact that after a token transfer, the approval status for the token is not revoked. Specifically, the `getApproved[_tokenId]` is not updated on transfer. This allows the previous owner (or any approved address) to reclaim the NFT by using the approval mechanism to re-transfer the token back to themselves. This is critical because the new owner of the NFT may lose their asset without realizing it, leading to potential exploitation, loss of assets, and decreased trust in the platform.

### Details

In the provided `approve` function, any user can approve themselves or another address for a specific token ID:

```solidity
/// @inheritdoc IERC721Metadata
function approve(address _approved, uint256 _tokenId) external payable {
    _requireAuthorised(msg.sender, _tokenId);
    getApproved[_tokenId] = _approved;
}
```

Since the approval is not revoked upon transfer, the previous owner retains the ability to re-transfer the NFT. The `_requireAuthorised` function is the only check on transfer permission:

```solidity
function _requireAuthorised(address _from, uint256 _tokenId) internal view {
    // revert if the sender is not authorised or the owner
    bool isAllowed =
        msg.sender == _from ||
        isApprovedForAll[_from][msg.sender] ||
        msg.sender == getApproved[_tokenId];

    require(isAllowed, "not allowed");
    require(ownerOf(_tokenId) == _from, "_from is not the owner!");
}
```

### Step-by-Step PoC:

1. **Initial Approval**: The owner of a token (`owner1`) approves an address (`addr2`) to transfer their token.
2. **Token Transfer**: The token is transferred from `owner1` to `newOwner`.
3. **Approval Not Revoked**: The approval for `addr2` is not revoked after the transfer.
4. **NFT Recovery**: `addr2` can still use their approval to transfer the NFT back to themselves, effectively recovering the NFT from `newOwner`.

There is no existing tests for this specific smart contract (because it is in solidity). A coded POC for this easy-to-understand vulnerability would involve to create all deployment logic.

### Recommended Mitigation Steps

To prevent this vulnerability, any existing approvals should be revoked when a token is transferred. This can be achieved by adding a line in the transfer function to clear the approval:

```solidity
getApproved[_tokenId] = address(0);
```

This line should be added to the token transfer function to ensure that any previously approved addresses cannot transfer the NFT after it has been sold or transferred to a new owner.

### Assessed type

Token-Transfer

**[af-afk (Superposition) confirmed via duplicate issue #56](https://github.com/code-423n4/2024-08-superposition-findings/issues/56#event-14300401337)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/160#issuecomment-2369621226):**
 > The submission details how approvals are not cleared whenever an NFT transfer occurs, permitting the NFT to be recovered after it has been transferred which breaks a crucial invariant of NFTs and would affect any and all integrations of the NFT (i.e., staking systems, marketplaces, etc.). As such, I believe a high-risk severity rating is appropriate.

***

## [[H-03] Missing `lower<upper` check in `mint_position`](https://github.com/code-423n4/2024-08-superposition-findings/issues/149)
*Submitted by [Q7](https://github.com/code-423n4/2024-08-superposition-findings/issues/149), also found by [aldarion](https://github.com/code-423n4/2024-08-superposition-findings/issues/122), [Nikki](https://github.com/code-423n4/2024-08-superposition-findings/issues/92), [prapandey031](https://github.com/code-423n4/2024-08-superposition-findings/issues/85), [SBSecurity](https://github.com/code-423n4/2024-08-superposition-findings/issues/71), [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/59), [nnez](https://github.com/code-423n4/2024-08-superposition-findings/issues/38), [Silvermist](https://github.com/code-423n4/2024-08-superposition-findings/issues/20), [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/18), [shaflow2](https://github.com/code-423n4/2024-08-superposition-findings/issues/9), [ABAIKUNANBAEV](https://github.com/code-423n4/2024-08-superposition-findings/issues/125), [nslavchev](https://github.com/code-423n4/2024-08-superposition-findings/issues/124), [rare\_one](https://github.com/code-423n4/2024-08-superposition-findings/issues/121), [OMEN](https://github.com/code-423n4/2024-08-superposition-findings/issues/106), [Testerbot](https://github.com/code-423n4/2024-08-superposition-findings/issues/105), [wasm\_it](https://github.com/code-423n4/2024-08-superposition-findings/issues/91), and [devival](https://github.com/code-423n4/2024-08-superposition-findings/issues/79)*

The current implementation does not perform a check for `lower < upper` during `mint_position`, while many other functions assume `lower < upper`. This discrepancy allows malicious actors to exploit inconsistencies in handling undefined behavior in other parts of the code for their benefit.

1. **Case when `lower = upper`:** In the `StorageTicks::update` function, liquidity can be added without issue because only one boundary and the current tick need to be passed, meaning it should function correctly even if the current tick equals the boundary. However, when calculating the amount of tokens required from the user, due to `lower = upper`, the calculation can only fall into the first and third branches. Here, `sqrt_ratio_a_x_96 = sqrt_ratio_a_x_96`, and the difference between these two values multiplies the result, leading to a token amount of 0 regardless of liquidity. A malicious user can exploit this implementation discrepancy to open a position with arbitrary liquidity value without consuming any tokens.

```rust
/* pkg/seawater/src/pool.rs */
170 | // calculate liquidity change and the amount of each token we need
171 | if delta != 0 {
172 |     let (amount_0, amount_1) = if self.cur_tick.get().sys() < lower {
...
183 | 
184 |         // we're below the range, we need to move right, we'll need more token0
185 |         (
186 |             sqrt_price_math::get_amount_0_delta(
187 |                 tick_math::get_sqrt_ratio_at_tick(lower)?,
188 |                 tick_math::get_sqrt_ratio_at_tick(upper)?,
189 |                 delta,
190 |             )?,
191 |             I256::zero(),
192 |         )
193 |     } else if self.cur_tick.get().sys() < upper {
194 |         // we're inside the range, the liquidity is active and we need both tokens
...
224 |     } else {
...
236 |         // we're above the range, we need to move left, we'll need token1
237 |         (
238 |             I256::zero(),
239 |             sqrt_price_math::get_amount_1_delta(
240 |                 tick_math::get_sqrt_ratio_at_tick(lower)?,
241 |                 tick_math::get_sqrt_ratio_at_tick(upper)?,
242 |                 delta,
243 |             )?,
244 |         )
245 |     };
```

While the attacker cannot directly profit by closing the position, these positions affect fee calculations. For example, in the provided PoC, the attacker can create a large number of empty positions within their liquidity range to collect significant fees from swapping users, inflating what would normally be a fee of 6 to 1605.

2. **Case when `lower > upper`:** Unlike the previous case, when `lower > upper` it is possible to create a position with both liquidity and balance. However, the potential issue arises when calling the `get_fee_growth_inside` function to calculate fees. This function also assumes `lower < upper` in its calculations, and passing `lower > upper` results in incorrect fee calculations, allowing the attacker to steal fees from other liquidity providers. However, the current implementation of `get_fee_growth_inside` has a bug where it does not correctly handle overflow as per the Uniswap V3 specification, rendering this exploit temporarily unusable.

### Proof of Concept

```rust
#[test]
fn lower_upper_eq_poc() {
    test_utils::with_storage::<_, Pools, _>(
        Some(address!("3f1Eae7D46d88F08fc2F8ed27FCb2AB183EB2d0E").into_array()), // sender
        None,
        None,
        None,
        |contract| -> Result<(), Vec<u8>> {
            let token0 = address!("9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0");
            contract.ctor(msg::sender(), Address::ZERO, Address::ZERO)?;
            contract.create_pool_D650_E2_D0(
                token0,
                U256::from_limbs([0, 42942782960, 0, 0]), 
                500,                                      // fee
                10,                                       // tick spacing
                u128::MAX,
            )?;
            contract.enable_pool_579_D_A658(token0, true)?;
            contract.mint_position_B_C5_B086_D(token0, 30000, 50000)?; // Init a normal position
            println!("Create normal position: {:?}", contract.update_position_C_7_F_1_F_740(token0, U256::from(0), 50000).unwrap()); 

            println!("Tick before swap {}", contract.cur_tick181_C6_F_D9(token0).unwrap());
            // Create 500 malicious empty positions
            for i in 0..2000 {
                contract.mint_position_B_C5_B086_D(token0, 30000+i*10, 30000+i*10)?;
                let (amount0, amount1) = contract.update_position_C_7_F_1_F_740(token0, U256::from(1+i), 100000000000).unwrap();
                assert!(amount0 == I256::ZERO && amount1 == I256::ZERO); // Attacker don't need any token
            }
            println!("Victim swap: {:?}", contract.swap_904369_B_E(
                token0,
                true,
                I256::try_from(10000_i32).unwrap(),
                U256::MAX,
            ).unwrap());
            println!("Tick after swap {}", contract.cur_tick181_C6_F_D9(token0).unwrap());
            println!("Refresh position {:?}", contract.update_position_C_7_F_1_F_740(token0, U256::from(0), 0).unwrap());
            println!("Fee owed: {:?}", contract.fees_owed_22_F28_D_B_D(token0, U256::from(0)).unwrap());
            Ok(())
        },
    )
    .unwrap()
}
```

### Recommended Mitigation Steps

Add `assert_or!(lower < upper, Error::InvalidTick)` check.

### Assessed type

Invalid Validation

**[af-afk (Superposition) confirmed via duplicate issue #59](https://github.com/code-423n4/2024-08-superposition-findings/issues/59#event-14293098456)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/149#issuecomment-2369613706):**
 > The Warden has properly identified that the creation of a position does not sufficiently validate its lower and upper tick values, permitting positions whereby the ticks are inverted or equal to be created with significant consequences.
> 
> I consider a high-risk severity rating appropriate and have penalized submissions that simply identified the vulnerability (i.e., as a medium, or simply noted it with no impact justification) by 25% (i.e., rewarded with a partial reward of 75%).

***

## [[H-04] Position's owed fees should allow underflow but it reverts instead, resulting in locked funds](https://github.com/code-423n4/2024-08-superposition-findings/issues/143)
*Submitted by [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/143), also found by [Tricko](https://github.com/code-423n4/2024-08-superposition-findings/issues/173) and [SBSecurity](https://github.com/code-423n4/2024-08-superposition-findings/issues/69)*

The math used to calculate how many fees are owed to the user does not allow underflows, but this is a necessary due to how the Uniswap logic works as fees can be negative. This impact adding/removing funds to a position, resulting in permanently locked funds due to a revert.

### Context

Similar to `Position's fee growth can revert resulting in funds permanently locked` but with a different function/root cause, both issues must be fixed separately.

### Proof of Concept

In `position.update` underflows are not allowed:

```rust
    pub fn update(
        &mut self,
        id: U256,
        delta: i128,
        fee_growth_inside_0: U256,
        fee_growth_inside_1: U256,
    ) -> Result<(), Error> {
        let mut info = self.positions.setter(id);

        let owed_fees_0 = full_math::mul_div(
            fee_growth_inside_0
->              .checked_sub(info.fee_growth_inside_0.get())
                .ok_or(Error::FeeGrowthSubPos)?,
            U256::from(info.liquidity.get()),
            full_math::Q128,
        )?;

        let owed_fees_1 = full_math::mul_div(
            fee_growth_inside_1
->              .checked_sub(info.fee_growth_inside_1.get())
                .ok_or(Error::FeeGrowthSubPos)?,
            U256::from(info.liquidity.get()),
            full_math::Q128,
        )?;

        let liquidity_next = liquidity_math::add_delta(info.liquidity.get().sys(), delta)?;

        if delta != 0 { 
            info.liquidity.set(U128::lib(&liquidity_next));
        }

        info.fee_growth_inside_0.set(fee_growth_inside_0);
        info.fee_growth_inside_1.set(fee_growth_inside_1);
        if !owed_fees_0.is_zero() {
            // overflow is the user's problem, they should withdraw earlier
            let new_fees_0 = info
                .token_owed_0
                .get()
                .wrapping_add(U128::wrapping_from(owed_fees_0));
            info.token_owed_0.set(new_fees_0);
        }
        if !owed_fees_1.is_zero() {
            let new_fees_1 = info
                .token_owed_1
                .get()
                .wrapping_add(U128::wrapping_from(owed_fees_1));
            info.token_owed_1.set(new_fees_1);
        }

        Ok(())
    }
```

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/position.rs#L52-L66>

While the original Uniswap version allows underflows:

```solidity
    uint128 tokensOwed0 =
        uint128(
            FullMath.mulDiv(
                feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                _self.liquidity,
                FixedPoint128.Q128
            )
        );
    uint128 tokensOwed1 =
        uint128(
            FullMath.mulDiv(
                feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                _self.liquidity,
                FixedPoint128.Q128
            )
        );
```

<https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/libraries/Position.sol#L61-L76>

The issue is that negative fees are expected due to how the formula works. It is explained in detail in this Uniswap's issue [here](https://github.com/Uniswap/v3-core/issues/573).

This function is used every time a position is updated, so it will be impossible to remove funds from it when the underflow happens because it will revert, resulting in locked funds.

### Recommended Mitigation Steps

Consider using `-` to let Rust underflow without errors in release mode:

```diff
        let owed_fees_0 = full_math::mul_div(
            fee_growth_inside_0
-               .checked_sub(info.fee_growth_inside_0.get())
-               .ok_or(Error::FeeGrowthSubPos)?,
+				- info.fee_growth_inside_0.get()
            U256::from(info.liquidity.get()),
            full_math::Q128,
        )?;

        let owed_fees_1 = full_math::mul_div(
            fee_growth_inside_1
-              .checked_sub(info.fee_growth_inside_1.get())
-              .ok_or(Error::FeeGrowthSubPos)?,
+			   - info.fee_growth_inside_1.get()
            U256::from(info.liquidity.get()),
            full_math::Q128,
        )?;
```

Alternatively, consider using `wrapping_sub`.

### Assessed type

Uniswap

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/143#issuecomment-2369630920):**
 > The submission and its duplicates properly identify that the `position.rs` file fails to permit underflows to occur when calculating fees which might result in inaccessible funds. I have personally observed this vulnerability in production, and I am inclined to agree with a high-risk severity rating as positions resulting in the underflow would effectively become permanently inaccessible.

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/143#event-14702643002)** 

***

## [[H-05] Parameter misordering in fee collection function causes denial of service and fee loss](https://github.com/code-423n4/2024-08-superposition-findings/issues/84)
*Submitted by [mashbust](https://github.com/code-423n4/2024-08-superposition-findings/issues/84), also found by [Q7](https://github.com/code-423n4/2024-08-superposition-findings/issues/152), [eta](https://github.com/code-423n4/2024-08-superposition-findings/issues/99), [d4r3d3v1l](https://github.com/code-423n4/2024-08-superposition-findings/issues/72), [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/60), [Tricko](https://github.com/code-423n4/2024-08-superposition-findings/issues/32), and [shaflow2](https://github.com/code-423n4/2024-08-superposition-findings/issues/3)*

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L1149>

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L1150>

### Impact

A critical bug has been identified in the `collect_protocol_7540_F_A_9_F` function of the Seawater Automated Market Maker (AMM) protocol. This vulnerability affects the core functionality of fee collection, rendering the system unable to transfer protocol fees from liquidity pools to the Seawater Admin or any designated recipient. The bug stems from incorrect parameter handling during the invocation of the `transfer_to_addr` function, which results in a complete failure of the fee withdrawal process.

The impact of this issue is severe:

1. **Denial of Service (DoS)**: The system's inability to transfer protocol fees halts the entire fee collection process, effectively disabling this core feature. Without this function, the Seawater Admin cannot retrieve fees collected from liquidity pools, meaning the protocol cannot generate or distribute earnings from the token swapping activity in these pools.

2. **Financial Loss**: Since the protocol relies on fees for its economic model, this bug causes a direct financial loss. The protocol's earnings from fees generated by liquidity pools are locked and inaccessible, leading to loss of funds. Over time, the fees accumulate in the pools, but they cannot be withdrawn by the Seawater Admin or any authorized recipient.

3. **Erosion of User Trust**: Protocol participants expect proper fee collection and distribution. If this feature fails, users may lose confidence in the protocol's reliability, leading to reduced engagement or participation. For liquidity providers and investors, this issue directly affects expected returns, as fees cannot be withdrawn.

4. **Long-term Protocol Viability**: If not addressed, this bug could harm the protocol’s long-term viability. Since the protocol is unable to collect revenue from its own pools, its ability to cover operational costs or distribute rewards is compromised. This could lead to a shutdown or significant degradation of the protocol’s functionality.

In summary, the failure to collect protocol fees undermines the core value proposition of the AMM protocol, resulting in a loss of funds, DoS of essential functionality, and the potential collapse of the protocol’s economic model if left unresolved.

### Proof of Concept

The bug exists in the fee collection logic of the `collect_protocol_7540_F_A_9_F` function located in `lib.rs`. This function is responsible for transferring collected protocol fees (in the form of tokens) from an AMM pool to the Seawater Admin or another recipient. However, incorrect parameter handling within the `transfer_to_addr` function causes the entire process to fail.

Here’s a detailed breakdown of the problematic code:

```rust
pub fn collect_protocol_7540_F_A_9_F(
    &mut self,
    pool: Address,
    amount_0: u128,
    amount_1: u128,
    recipient: Address,
) -> Result<(u128, u128), Revert> {
    assert_eq_or!(
        msg::sender(),
        self.seawater_admin.get(),
        Error::SeawaterAdminOnly
    );

    let (token_0, token_1) = self
        .pools
        .setter(pool)
        .collect_protocol(amount_0, amount_1)?;

    // Incorrect transfer logic
    erc20::transfer_to_addr(recipient, pool, U256::from(token_0))?;
    erc20::transfer_to_addr(recipient, FUSDC_ADDR, U256::from(token_1))?;

    #[cfg(feature = "log-events")]
    evm::log(events::CollectProtocolFees {
        pool,
        to: recipient,
        amount0: token_0,
        amount1: token_1,
    });

    // transfer tokens
    Ok((token_0, token_1))
}
```

The issue arises in the following lines:

```rust
erc20::transfer_to_addr(recipient, pool, U256::from(token_0))?;
erc20::transfer_to_addr(recipient, FUSDC_ADDR, U256::from(token_1))?;
```

In this block:
- **`recipient`** is incorrectly passed as the token address.
- **`pool` or `FUSDC_ADDR`** is incorrectly passed as the recipient.

This order causes the `transfer_to_addr` function to fail because it expects the **first parameter** to be the token address and the **second parameter** to be the recipient address. Here's the correct signature of the `transfer_to_addr` function from `wasm_erc20.rs`:

```rust
pub fn transfer_to_addr(token: Address, recipient: Address, amount: U256) -> Result<(), Error> {
    safe_transfer(token, recipient, amount)
}
```

Since the parameters are passed in the wrong order, the `transfer_to_addr` function fails, leading to a complete halt of the fee transfer process. As a result, the collected fees cannot be moved from the pools to the Seawater Admin or recipient, effectively blocking the protocol’s ability to distribute or utilize these funds.

### Steps to Reproduce the Issue

1. Call the `collect_protocol_7540_F_A_9_F` function with a valid pool address, token amounts, and recipient address.
2. The function will attempt to transfer the protocol fees using `erc20::transfer_to_addr`.
3. Since the arguments are incorrectly passed (with the recipient and token address swapped), the transaction will fail, and no tokens will be transferred.

**Failed Transaction Log**:

```
    [18881] collect_protocol_7540_F_A_9_F::collect_fees()
        ├─ [11555] erc20::transfer_to_addr(token: [recipient], pool: [token], 1)
        │   └─ ← [Revert] 
        └─ ← [Revert] 
```

This log highlights the issue that the `transfer_to_addr` function is attempting to use the recipient address as the token address, and the pool address as the recipient. This mismatch causes the transfer to fail, preventing the collected protocol fees from being withdrawn.

### Tools Used

- **Rust Analyzer**: Employed to debug and trace the logic flow of the contract code, helping to identify the parameter mismatch issue.
- **test-node**: Utilized to track failed transactions and confirm the DoS condition caused by the bug.
- **Visual Studio Code (VSCode)**: Main code editor used to examine and analyze the source code of the protocol.

### Recommended Mitigation Steps

To fix this issue, the arguments passed to the `erc20::transfer_to_addr` function need to be correctly ordered, ensuring that the token address is provided first, followed by the recipient address. This correction will allow the transfer of protocol fees from the liquidity pools to the designated recipient.

**Corrected Code**:

```rust
erc20::transfer_to_addr(pool, recipient, U256::from(token_0))?;
erc20::transfer_to_addr(FUSDC_ADDR, recipient, U256::from(token_1))?;
```

This update reverses the order of parameters, passing the **token address as the first parameter** and the **recipient address as the second parameter**, as expected by the `transfer_to_addr` function. By implementing this fix, the protocol will correctly transfer collected fees, ensuring that the Seawater Admin or any authorized recipient can successfully withdraw fees from the AMM pools.

### Additional Steps to Consider

1. **Add Unit Tests**: To prevent this issue from recurring, add specific unit tests to validate the correct behavior of the `collect_protocol_7540_F_A_9_F` function. These tests should confirm that fees can be collected and transferred without errors.

2. **Error Handling Improvements**: Consider adding more explicit error messages to the `transfer_to_addr` function to help identify issues during fee transfers. This could include checking whether the token address and recipient address are valid before proceeding with the transfer.

3. **Gas Efficiency**: After resolving this issue, it’s advisable to audit the overall gas usage of the fee collection process to ensure that no unnecessary operations are being performed during the transfer of protocol fees.

### Assessed type

DoS

**[af-afk (Superposition) confirmed via duplicate issue #60](https://github.com/code-423n4/2024-08-superposition-findings/issues/60#event-14285026187)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/84#issuecomment-2369612787):**
 > The Warden has identified that an incorrect order of arguments in the EIP-20 transfer calls within the `lib::collect_protocol_7540_F_A_9_F` function will cause a token transfer to be attempted with the `recipient` address as the "token" thereby failing on each invocation.
> 
> I believe a high severity rating is appropriate given that funds are directly lost and are irrecoverable due to an im proper implementation of the protocol fee claim mechanism.

***

## [[H-06] `get_fee_growth_inside` in `tick.rs` should allow for `underflow`/`overflow` but doesn't](https://github.com/code-423n4/2024-08-superposition-findings/issues/46)
*Submitted by [SBSecurity](https://github.com/code-423n4/2024-08-superposition-findings/issues/46), also found by [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/142), [ZanyBonzy](https://github.com/code-423n4/2024-08-superposition-findings/issues/136), [aldarion](https://github.com/code-423n4/2024-08-superposition-findings/issues/118), [peanuts](https://github.com/code-423n4/2024-08-superposition-findings/issues/111), [0xhashiman](https://github.com/code-423n4/2024-08-superposition-findings/issues/86), [Tricko](https://github.com/code-423n4/2024-08-superposition-findings/issues/40), and [Q7](https://github.com/code-423n4/2024-08-superposition-findings/issues/151)*

When operations need to calculate the `Superposition` position's fee growth, it uses a similar function implemented by [uniswap v3](https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/PositionValue.sol#L145-L166).

However, according to this known issue, [Uniswap/v3-core#573](https://github.com/Uniswap/v3-core/issues/573), the contract implicitly relies on underflow/overflow when calculating the fee growth if underflow is prevented, some operations that depend on fee growth will revert.

### Proof of Concept

It can be observed that the current implementation of `tick::get_fee_growth_inside` does not allow underflow/overflow to happen when calculating `fee_growth_inside_0` and `fee_growth_inside_1` because the contract uses [checked math](https://docs.rs/num/latest/num/trait.CheckedSub.html) with additional overflow/underflow checks; which will perform subtraction that returns `none` instead of wrapping around on underflow in [tick.rs](https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/tick.rs#L125C5-L246C6).

<details>

```rust
pub fn get_fee_growth_inside(
    &mut self,
    lower_tick: i32,
    upper_tick: i32,
    cur_tick: i32,
    fee_growth_global_0: &U256,
    fee_growth_global_1: &U256,
) -> Result<(U256, U256), Error> {
    // the fee growth inside this tick is the total fee
    // growth, minus the fee growth outside this tick
    let lower = self.ticks.get(lower_tick);
    let upper = self.ticks.get(upper_tick);

    let (fee_growth_below_0, fee_growth_below_1) = if cur_tick >= lower_tick {
        #[cfg(feature = "testing-dbg")]
        dbg!((
            "cur_tick >= lower_tick",
            current_test!(),
            lower.fee_growth_outside_0.get().to_string(),
            lower.fee_growth_outside_1.get().to_string()
        ));

        (
            lower.fee_growth_outside_0.get(),
            lower.fee_growth_outside_1.get(),
        )
    } else {
        #[cfg(feature = "testing-dbg")]
        dbg!((
            "cur_tick < lower_tick",
            current_test!(),
            fee_growth_global_0,
            fee_growth_global_1,
            lower.fee_growth_outside_0.get().to_string(),
            lower.fee_growth_outside_1.get().to_string()
        ));

        (
            fee_growth_global_0
                .checked_sub(lower.fee_growth_outside_0.get())
                .ok_or(Error::FeeGrowthSubTick)?,
            fee_growth_global_1
                .checked_sub(lower.fee_growth_outside_1.get())
                .ok_or(Error::FeeGrowthSubTick)?,
        )
    };

    let (fee_growth_above_0, fee_growth_above_1) = if cur_tick < upper_tick {
        #[cfg(feature = "testing-dbg")]
        dbg!((
            "cur_tick < upper_tick",
            current_test!(),
            upper.fee_growth_outside_0.get().to_string(),
            upper.fee_growth_outside_1.get().to_string()
        ));

        (
            upper.fee_growth_outside_0.get(),
            upper.fee_growth_outside_1.get(),
      )
    } else {
        #[cfg(feature = "testing-dbg")]
        dbg!((
            "cur_tick >= upper_tick",
            current_test!(),
            fee_growth_global_0,
            fee_growth_global_1,
            upper.fee_growth_outside_0.get(),
            upper.fee_growth_outside_1.get()
        ));

        (
            fee_growth_global_0
                .checked_sub(upper.fee_growth_outside_0.get())
                .ok_or(Error::FeeGrowthSubTick)?,
            fee_growth_global_1
                .checked_sub(upper.fee_growth_outside_1.get())
                .ok_or(Error::FeeGrowthSubTick)?,
        )
    };

    #[cfg(feature = "testing-dbg")] // REMOVEME
    {
        if *fee_growth_global_0 < fee_growth_below_0 {
            dbg!((
                "fee_growth_global_0 < fee_growth_below_0",
                current_test!(),
                fee_growth_global_0.to_string(),
                fee_growth_below_0.to_string()
            ));
        }
        let fee_growth_global_0 = fee_growth_global_0.checked_sub(fee_growth_below_0).unwrap();
        if fee_growth_global_0 < fee_growth_above_0 {
            dbg!((
                "fee_growth_global_0 < fee_growth_above_0",
                current_test!(),
                fee_growth_global_0.to_string(),
                fee_growth_above_0.to_string()
            ));
        }
    }

    #[cfg(feature = "testing-dbg")]
    dbg!((
        "final stage checked sub below",
        current_test!(),
        fee_growth_global_0
            .checked_sub(fee_growth_below_0)
            .and_then(|x| x.checked_sub(fee_growth_above_0))
    ));

    Ok((
        fee_growth_global_0
            .checked_sub(fee_growth_below_0)
            .and_then(|x| x.checked_sub(fee_growth_above_0))
            .ok_or(Error::FeeGrowthSubTick)?,
        fee_growth_global_1
            .checked_sub(fee_growth_below_1)
            .and_then(|x| x.checked_sub(fee_growth_above_1))
            .ok_or(Error::FeeGrowthSubTick)?,
    ))
}
```

</details>

Especially the last lines where we have `fee_growth_global_0 - fee_growth_below_0 - fee_growth_above_0` and `fee_growth_global_1 - fee_growth_below_1 - fee_growth_above_1`.

In case either one of the calculation underflows we will receive `Error::FeeGrowthSubTick` instead of being wrapped and continue working.

Uniswap allows such underflows to happen because [`PositionLibrary`](https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/PositionValue.sol#L145-L166) works with Solidity version `< 0.8`. Otherwise, this will impact crucial operations that rely on this call, such as liquidation, and will revert unexpectedly. This behavior is quite often, especially for pools that use lower fees.

Furthermore, one of the Main Invariants in the README mentioned that Superposition should follow the UniswapV3 math `faithfully`, which is not the case here, violating the invariant.

<https://github.com/code-423n4/2024-08-superposition?tab=readme-ov-file#main-invariants>

### Tools Used

H-04 from [Particle Leverage AMM](https://code4rena.com/reports/2023-12-particle#h-04-underflow-could-happened-when-calculating-uniswap-v3-positions-fee-growth-and-can-cause-operations-to-revert).

### Recommended Mitigation Steps

Use `unsafe`/`unchecked` math when calculating the fee growths.

### Assessed type

Under/Overflow

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/46#event-14300582618)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/46#issuecomment-2369629602):**
 > The submission and its duplicates properly identify that the `tick.rs` file fails to permit underflows to occur when calculating fees which might result in inaccessible funds. I have personally observed this vulnerability in production, and I am inclined to agree with a high-risk severity rating as positions resulting in the underflow would effectively become permanently inaccessible.

***

## [[H-07] `swapOut` functions have invalid slippage check, causing user loss of funds](https://github.com/code-423n4/2024-08-superposition-findings/issues/35)
*Submitted by [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/35), also found by [Testerbot](https://github.com/code-423n4/2024-08-superposition-findings/issues/53)*

In SeawaterAMM.sol, `swapOut5E08A399` and `swapOutPermit23273373B` are intended to allow `usdc(token1) -> pool(token0)` swap with slippage check. See [ISeawaterAMM's doc](https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/ISeawaterAMM.sol#L47).

However, both functions have incorrect slippage checks. We see in `swapOut5E08A399` `swapAmountOut` is used to check with `minOut`. But `swapAmountOut` is actually `usdc(token1)`, not the output `token(token0)`. This uses an incorrect variable to check slippage.

```solidity
    function swapOut5E08A399(
        address token,
        uint256 amountIn, //@audit-info note: this is usdc(token1)
        uint256 minOut
    ) external returns (int256, int256) {
            (bool success, bytes memory data) = _getExecutorSwap().delegatecall(
            abi.encodeCall(
                ISeawaterExecutorSwap.swap904369BE,
                (token, false, int256(amountIn), type(uint256).max)
            )
        );
        require(success, string(data));
        //@audit-info note: swapAmountIn <=> token0 , swapAmountOut <=> token1
|>      (int256 swapAmountIn, int256 swapAmountOut) = abi.decode(
            data,
            (int256, int256)
        );
       //@audit This should use token0 value, not token1
|>     require(swapAmountOut >= int256(minOut), "min out not reached!");
       return (swapAmountIn, swapAmountOut);
    }
```

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L317

For reference, in the swap facet, `swap_internal` called in the flow returns `Ok((amount_0, amount_1))`. This means `swapAmountOut` refers to `token1`, the input token amount.

```rust
//pkg/seawater/src/lib.rs
    pub fn swap_internal(
        pools: &mut Pools,
        pool: Address,
        zero_for_one: bool,
        amount: I256,
        price_limit_x96: U256,
        permit2: Option<Permit2Args>,
    ) -> Result<(I256, I256), Revert> {
        let (amount_0, amount_1, _ending_tick) =
            pools
                .pools
                .setter(pool)
                .swap(zero_for_one, amount, price_limit_x96)?;
...
        Ok((amount_0, amount_1))
```

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L194

`swapOutPermit23273373B` also has the same erroneous slippage check:

```solidity
//pkg/sol/SeawaterAMM.sol
    function swapOutPermit23273373B(address token, uint256 amountIn, uint256 minOut, uint256 nonce, uint256 deadline, uint256 maxAmount, bytes memory sig) external returns (int256, int256) {
...
|>     (int256 swapAmountIn, int256 swapAmountOut) = abi.decode(data, (int256, int256));
|>      require(swapAmountOut >= int256(minOut), "min out not reached!");
        return (swapAmountIn, swapAmountOut);
    }
```

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L339

Invalid slippage checks will cause users to lose funds during swaps.

### Recommended Mitigation Steps

Consider changing to:

```solidity
...
        (int256 swapAmountOut, int256 swapAmountIn) = abi.decode(
            data,
            (int256, int256)
        );
                require(uint256(-swapAmountOut) >= minOut, "min out not reached!");
                return (swapAmountOut, swapAmountIn);
```

### Assessed type

Error

**[af-afk (Superposition) confirmed via duplicate issue #53](https://github.com/code-423n4/2024-08-superposition-findings/issues/53#event-14300382917)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/35#issuecomment-2369625627):**
 > The Warden has identified that the slippage protections of the swap-out functions are incorrect and thus ineffective due to validating an incorrect amount, resulting in either incorrect successful executions or incorrect failed executions depending on the price relation between the two assets.
> 
> A medium-risk severity rating is appropriate given that a subset of the system's functionality is affected with slippage being the component affected.

**[0xsomeone (judge) increased severity to High and commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/35#issuecomment-2396701236):**
 > After revisiting this submission in light of the comments shared in [Issue #53](https://github.com/code-423n4/2024-08-superposition-findings/issues/53#issuecomment-2374785547), I am inclined to upgrade it to a high-risk severity rating as user funds are directly impacted.

***

# Medium Risk Findings (12)
## [[M-01] `_onTransferReceived()` does not work as intended](https://github.com/code-423n4/2024-08-superposition-findings/issues/148)
*Submitted by [adeolu](https://github.com/code-423n4/2024-08-superposition-findings/issues/148), also found by debo ([1](https://github.com/code-423n4/2024-08-superposition-findings/issues/165), [2](https://github.com/code-423n4/2024-08-superposition-findings/issues/127)), [Tigerfrake](https://github.com/code-423n4/2024-08-superposition-findings/issues/163), [0xAleko](https://github.com/code-423n4/2024-08-superposition-findings/issues/159), [0xastronatey](https://github.com/code-423n4/2024-08-superposition-findings/issues/158), [zhaojohnson](https://github.com/code-423n4/2024-08-superposition-findings/issues/157), [nslavchev](https://github.com/code-423n4/2024-08-superposition-findings/issues/150), [ZanyBonzy](https://github.com/code-423n4/2024-08-superposition-findings/issues/140), [Rhaydden](https://github.com/code-423n4/2024-08-superposition-findings/issues/135), [Nikki](https://github.com/code-423n4/2024-08-superposition-findings/issues/133), [ABAIKUNANBAEV](https://github.com/code-423n4/2024-08-superposition-findings/issues/131), [Agontuk](https://github.com/code-423n4/2024-08-superposition-findings/issues/110), [OMEN](https://github.com/code-423n4/2024-08-superposition-findings/issues/107), [Testerbot](https://github.com/code-423n4/2024-08-superposition-findings/issues/101), [mashbust](https://github.com/code-423n4/2024-08-superposition-findings/issues/96), [swapnaliss](https://github.com/code-423n4/2024-08-superposition-findings/issues/94), [Sparrow](https://github.com/code-423n4/2024-08-superposition-findings/issues/90), [NexusAudits](https://github.com/code-423n4/2024-08-superposition-findings/issues/81), [SBSecurity](https://github.com/code-423n4/2024-08-superposition-findings/issues/73), [Bauchibred](https://github.com/code-423n4/2024-08-superposition-findings/issues/67), [Decap](https://github.com/code-423n4/2024-08-superposition-findings/issues/55), [wasm\_it](https://github.com/code-423n4/2024-08-superposition-findings/issues/42), [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/28), [SpicyMeatball](https://github.com/code-423n4/2024-08-superposition-findings/issues/26), and [dreamcoder](https://github.com/code-423n4/2024-08-superposition-findings/issues/109)*

`_onTransferReceived` does not work as intended or described in the function [`natspec`](https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L65-L67).

- It will not revert when the recipient does not implement `onERC721Received()` function correctly (does not return `onERC721Received().selector`).
- It will revert when the recipient implements `onERC721Received()` function correctly and as described/specified by the [EIP 712](https://eips.ethereum.org/EIPS/eip-721#specification) (returns `onERC721Received().selector`).
- This will prevent transfers to contracts that have correctly implemented the `ERC721TokenReceiver` interface to accept safe token transfers via `safeTransferFrom()`.

### Proof of Concept

`_onTransferReceived()` has a require statement that will pass when the recipient does not return the `IERC721TokenReceiver.onERC721Received()` selector. [EIP 721](https://eips.ethereum.org/EIPS/eip-721#specification) defines that if a recipient is a contract, it should implement the `IERC721TokenReceiver.onERC721Received()` function and that function must return the `IERC721TokenReceiver.onERC721Received()` selector for it to be recognized as a valid erc721 token receiver.

Snippet of the faulty require statement below:

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L82-L95>

```solidity
        bytes4 data = IERC721TokenReceiver(_to).onERC721Received(
            _sender,
            _from,
            _tokenId,

            // this is empty byte data that can be optionally passed to
            // the contract we're confirming is able to receive NFTs
            ""
        );

        require(
            data != IERC721TokenReceiver.onERC721Received.selector,
            "bad nft transfer received data"
        );
```

We can see that the require statement expects the data returned from the erc721 token receiver to **not be equal** to `IERC721TokenReceiver.onERC721Received.selector`. This means that if the recipient implements the `onERC721Received` function correctly and returns `IERC721TokenReceiver.onERC721Received.selector`, the require statement in function `_onTransferReceived()` will revert the whole transfer.

### Coded POC

Create foundry test repo and run the file below in test folder:

<details>

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

/// @dev Note: the ERC-165 identifier for this interface is 0x150b7a02.
interface IERC721TokenReceiver {
    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient
    ///  after a `transfer`. This function MAY throw to revert and reject the
    ///  transfer. Return of other than the magic value MUST result in the
    ///  transaction being reverted.
    ///  Note: the contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _tokenId The NFT identifier which is being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    ///  unless throwing
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory _data
    ) external returns (bytes4);
}

/*
 * OwnershipNFTs is a simple interface for tracking ownership of
 * positions in the Seawater Stylus contract.
 */
contract OwnershipNFTs {
    /**
     * @notice _onTransferReceived by calling the callback `onERC721Received`
     *         in the recipient if they have codesize > 0. if the callback
     *         doesn't return the selector, revert!
     * @param _sender that did the transfer
     * @param _from owner of the NFT that the sender is transferring
     * @param _to recipient of the NFT that we're calling the function on
     * @param _tokenId that we're transferring from our internal storage
     */
    //  _onTransferReceived() is exact same function that is in the codebase, with no changes to logic whatsoever
    function _onTransferReceived(
        address _sender,
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        // only call the callback if the receiver is a contract
        if (_to.code.length == 0) return;

        bytes4 data = IERC721TokenReceiver(_to).onERC721Received(
            _sender,
            _from,
            _tokenId,
            // this is empty byte data that can be optionally passed to
            // the contract we're confirming is able to receive NFTs
            ""
        );

        require(
            data != IERC721TokenReceiver.onERC721Received.selector,
            "bad nft transfer received data"
        );
    }

    // mock wrapper function that calls the internal _onTransferReceived()
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        _onTransferReceived(msg.sender, _from, _to, _tokenId);
    }
}

contract MockCompliantReceiver is IERC721TokenReceiver {
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory _data
    ) external returns (bytes4) {
        return IERC721TokenReceiver.onERC721Received.selector;
    }
}

contract receiverTest is Test {
    MockCompliantReceiver compliant_receiver;
    OwnershipNFTs ownershipNft;

    function setUp() public {
        //deploy MockCompliantReceiver
        compliant_receiver = new MockCompliantReceiver();

        //deploy ownershipNft contract
        ownershipNft = new OwnershipNFTs();
    }

    function test_revertForCompliantReceiver() public {
        /* we expect the call to revert because of the faulty require statement */
        /** this shows that the _onTransferReceived will always reject transfers to a contract that is 
         IERC721TokenReceiver compliant.  */
         
        vm.expectRevert(bytes("bad nft transfer received data"));
        ownershipNft.safeTransferFrom(
            msg.sender,
            payable(address(compliant_receiver)), //param `to` is set to be the compliant receiver here
            1
        );
    }
}
```

</details>

### Recommended Mitigation Steps

Change the `!=` in the  require statement to `==`:

```solidity
        require(
            data == IERC721TokenReceiver.onERC721Received.selector,
            "bad nft transfer received data"
        );
```

### Assessed type

Context

**[af-afk (Superposition) confirmed and commented via duplicate issue #55](https://github.com/code-423n4/2024-08-superposition-findings/issues/55#issuecomment-2354630264):**
> We don't believe this is a high risk submission since assets cannot be stolen. Maybe transfers to up to spec contracts could not be used, but that's just frustrating for users.

**[0xsomeone (judge) decreased severity to Medium and commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/148#issuecomment-2369622659):**
 > The submission details how the EIP-721 safe transfers will fail to validate the return data properly, causing EIP-721 callback integrations to fail for the token.
> 
> I believe a medium-risk severity rating is better suited for this submission given that assets are not at risk and functionality becomes inaccessible that should normally be circumventable.

***

## [[M-02] `bytes data` param is not passed to ERC721 recipient as expected by EIP-721](https://github.com/code-423n4/2024-08-superposition-findings/issues/146)
*Submitted by [adeolu](https://github.com/code-423n4/2024-08-superposition-findings/issues/146)*

ERC-721 standard has two variations of the `safeTransferFrom()`, one with no `bytes data` param and the other with a `bytes data` param. The second variation that accepts a `bytes data` param is meant to pass that data param to the token recipient during the `IERC721TokenReceiver. onERC721Received()` call. This `bytes data` param is usually an encoding of extra variables which is used by the recipient contract for the extra logic it will perform as it receives a token.

[OwnershipNFTs.sol](https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/sol/OwnershipNFTs.sol) is ERC721 compliant and so it has two `safeTransferFrom()` functions but the  second `safeTransferFrom()` has a `bytes data` param which is not passed into the recipient during `IERC721TokenReceiver. onERC721Received()` call to recipient. It accepts the `bytes data` param but doesn't use it.

```solidity
    /// @inheritdoc IERC721Metadata
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata /* _data */
    ) external payable {
        _transfer(_from, _to, _tokenId);
        _onTransferReceived(msg.sender, _from, _to, _tokenId); 
```

As we can see above, the bytes param is declared as an arbitrary param, perhaps just to conform to IERC721 spec but the bytes param is not used in the logic at all, and it ought to be used as defined [here](https://eips.ethereum.org/EIPS/eip-721#specification)  in the EIP.

> /// @param data Additional data with no specified format, sent in call to `_to`

For contracts that integrate OwnershipNFTs or receive transfers, if they have logic which require the additional bytes passed in via the second `safeTransferFrom()`, they will be unable to execute this logic and may reject the transfers; or revert as this `bytes data` supplied by the caller of the `safeTransferFrom()` is not passed into them via the `IERC721TokenReceiver.onERC721Received()` call. Instead, empty bytes is passed into `IERC721TokenReceiver.onERC721Received()`, as seen [here](https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L89).

Below is a POC which shows how passing empty bytes by default instead of passing the bytes specified by the sender into a tokenReceiver may cause the transfer to fail.

Run with `forge test`:

<details>

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

/// @dev Note: the ERC-165 identifier for this interface is 0x150b7a02.
interface IERC721TokenReceiver {
    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the recipient
    ///  after a `transfer`. This function MAY throw to revert and reject the
    ///  transfer. Return of other than the magic value MUST result in the
    ///  transaction being reverted.
    ///  Note: the contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _tokenId The NFT identifier which is being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    ///  unless throwing
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory _data
    ) external returns (bytes4);
}

/*
 * OwnershipNFTs is a simple interface for tracking ownership of
 * positions in the Seawater Stylus contract.
 */
contract OwnershipNFTs {
    /**
     * @notice _onTransferReceived by calling the callback `onERC721Received`
     *         in the recipient if they have codesize > 0. if the callback
     *         doesn't return the selector, revert!
     * @param _sender that did the transfer
     * @param _from owner of the NFT that the sender is transferring
     * @param _to recipient of the NFT that we're calling the function on
     * @param _tokenId that we're transferring from our internal storage
     */
    //  _onTransferReceived() is exact same function that is in the codebase, with no changes to logic whatsoever
    function _onTransferReceived(
        address _sender,
        address _from,
        address _to,
        uint256 _tokenId
    ) internal {
        // only call the callback if the receiver is a contract
        if (_to.code.length == 0) return;

        bytes4 data = IERC721TokenReceiver(_to).onERC721Received(
            _sender,
            _from,
            _tokenId,
            // this is empty byte data that can be optionally passed to
            // the contract we're confirming is able to receive NFTs
            ""
        );

        //@audit we don't expect execution to get here, revert should happen in the call to _to because of decoding of empty bytes in _to logic
        // require(
        //     data != IERC721TokenReceiver.onERC721Received.selector,
        //     "bad nft transfer received data"
        // );
    }

    //the function below is same as seen here -> https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L148-L157
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata /** _data */
    ) external {
        //_transfer(_from, _to, _tokenId);
        _onTransferReceived(msg.sender, _from, _to, _tokenId);
    }
}

contract MockCompliantReceiver is IERC721TokenReceiver {
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory _data
    ) external returns (bytes4) {
        //get values in bytes memory _data
        (uint timestamp, uint commandID) = abi.decode(_data, (uint, uint));

        return IERC721TokenReceiver.onERC721Received.selector;
    }
}

contract receiverTest is Test {
    MockCompliantReceiver compliant_receiver;
    OwnershipNFTs ownershipNft;

    function setUp() public {
        //deploy MockCompliantReceiver
        compliant_receiver = new MockCompliantReceiver();

        //deploy ownershipNft contract
        ownershipNft = new OwnershipNFTs();
    }

    function test_revertForCompliantReceiver() public {
        //data to be encoded and expected passed into the recipient contract by a sender/user
        bytes memory data = abi.encode(block.timestamp, 10);


        /* we expect the call to revert because of the decoding of the empty bytes data passed into _to.OnERC721Received() */

        vm.expectRevert();
        ownershipNft.safeTransferFrom(
            msg.sender,
            payable(address(compliant_receiver)), //param `to` is set to be the compliant receiver here
            1,
            data
        );
    }
}
```

</details>

### Impact

The implementation of the `safeTransferFrom()` function that accepts additional bytes is not sufficient and not as defined by the EIP-721 spec. The bytes param passed in by a caller is not sent to the recipient contract. Receiving contracts may need to decode this bytes param, but since empty bytes are passed in to recipient by default in OwnershipNfts this will cause reverts/inaccessibility to this function/feature of the ERC721.

### Recommended Mitigation Steps

The issue stems from the `_onTransferReceived()` not accepting a `bytes data` param. Modify it to accept it and pass that param into the `IERC721TokenReceiver.onERC721Received()` call. Then in each `safeTransferFrom()`, pass the bytes param into the modified `_onTransferReceived()`. If the `safeTransferFrom()` accepts no bytes param, pass empty bytes into `_onTransferReceived()`.

```solidity
    function _onTransferReceived(
        address _sender,
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata data
    ) internal {
    ...

        bytes4 data = IERC721TokenReceiver(_to).onERC721Received(
            _sender,
            _from,
            _tokenId, 
            data
        );
      ...
    }


    /// @inheritdoc IERC721Metadata
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        _transfer(_from, _to, _tokenId);
        _onTransferReceived(msg.sender, _from, _to, _tokenId, "");
    }

    /// @inheritdoc IERC721Metadata
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata  _data 
    ) external payable {
        _transfer(_from, _to, _tokenId);
        _onTransferReceived(msg.sender, _from, _to, _tokenId, _data);
    }
```

### Assessed type

ERC721

**[0xsomeone (judge) decreased severity to Low](https://github.com/code-423n4/2024-08-superposition-findings/issues/146#issuecomment-2369627770)**

**[adeolu (warden) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/146#issuecomment-2369894979):**
 > @0xsomeone - I would like implore you to review your decision on this finding as it is quite different from the findings it was grouped with. 
> 
> This finding does not just talk about EIP-721 compliance but spotlights an implementation flaw in the callback to the token receiver. The hardcoding of the empty bytes passed to the token receiver when the receiver is a contract obstructs the use case of the ERC721Receiver callback/hook . The use cases of this hooks are
> 
> 1. Ensure that a contract is ready to receive the erc721 token.
> 2. Allow for execution of additional custom logic on receipt of the token. 
> 3. Allow for sender to communicate with receiving contract via the bytes data that should be passed into it via the callback. This bytes data will then be used in the additional logic to be executed upon the contract receiving the token. 
> 
> The OwnershipNFT as it is prevents use cases 2 and 3 and in some cases will may prevent 1 because if a contract that has custom logic which requires bytes to be passed in, it will never be ready to receive the token. 
> 
> Bytes data passed in by a token sender should be propagated to the token receiver contracts. This is the correct, expected and complete implementation of `safeTransferFrom() -> receiver.OnERC721Recevied()`  callback flow.

**[0xsomeone (judge) increased severity to Medium and commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/146#issuecomment-2396661519):**
 > @adeolu - Indeed, this finding seems to have been grouped incorrectly during the validation phase. Per the rationale laid out in [Issue #55](https://github.com/code-423n4/2024-08-superposition-findings/issues/55), the EIP-721 callback feature was deliberately implemented and does not forward the `_data` payload as described.
> 
> A medium severity rating for this submission, similar to #55, is appropriate.

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/146#event-14710495717)** 

***

## [[M-03] Wrong liquidity formula used](https://github.com/code-423n4/2024-08-superposition-findings/issues/77)
*Submitted by [prapandey031](https://github.com/code-423n4/2024-08-superposition-findings/issues/77)*

The protocol provides a function to increment a position's liquidity:

```solidity
    function incrPositionC3AC7CAA(
        address pool,
        uint256 id,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external returns (uint256, uint256);
```

It is present in the SeawaterAmm.sol:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/sol/SeawaterAMM.sol#L464>

```solidity
    function incrPositionC3AC7CAA(
        address /* pool */,
        uint256 /* id */,
        uint256 /* amount0Min */,
        uint256 /* amount1Min */,
        uint256 /* amount0Desired */,
        uint256 /* amount1Desired */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorUpdatePosition());
    }
```

It calls a function in lib.rs:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/lib.rs#L914>

```rust
    #[allow(non_snake_case)]
    pub fn incr_position_C_3_A_C_7_C_A_A(
        &mut self,
        pool: Address,
        id: U256,
        amount_0_min: U256,
        amount_1_min: U256,
        amount_0_desired: U256,
        amount_1_desired: U256,
    ) -> Result<(U256, U256), Revert> {
        self.adjust_position_internal(
            pool,
            id,
            amount_0_min,
            amount_1_min,
            amount_0_desired,
            amount_1_desired,
            false,
            None,
        )
    }
```

This calls an internal function in lib.rs:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/lib.rs#L730>

```solidity
    #[allow(clippy::too_many_arguments)]
    pub fn adjust_position_internal(
        &mut self,
        pool: Address,
        id: U256,
        amount_0_min: U256,
        amount_1_min: U256,
        amount_0_desired: U256,
        amount_1_desired: U256,
        giving: bool,
        permit2: Option<(Permit2Args, Permit2Args)>,
    ) -> Result<(U256, U256), Revert> {
        assert_eq_or!(
            msg::sender(),
            self.position_owners.get(id),
            Error::PositionOwnerOnly
        );

        let (amount_0, amount_1) = self.pools.setter(pool).adjust_position(
            id,
            amount_0_desired,
            amount_1_desired,
            giving,
        )?;
        .
        .
        .
    }
```

This function calls a function in pool.rs:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L253>

```rust
    pub fn adjust_position(
        &mut self,
        id: U256,
        amount_0: U256,
        amount_1: U256,
        giving: bool,
    ) -> Result<(I256, I256), Revert> {
        // calculate the delta using the amounts that we have here, guaranteeing
        // that we don't dip below the amount that's supplied as the minimum.

        let position = self.positions.positions.get(id);

        let sqrt_ratio_x_96 = tick_math::get_sqrt_ratio_at_tick(self.get_cur_tick().as_i32())?;
        let sqrt_ratio_a_x_96 = tick_math::get_sqrt_ratio_at_tick(position.lower.get().as_i32())?;
        let sqrt_ratio_b_x_96 = tick_math::get_sqrt_ratio_at_tick(position.upper.get().as_i32())?;

        let mut delta = sqrt_price_math::get_liquidity_for_amounts(
            sqrt_ratio_x_96,   // cur_tick
            sqrt_ratio_a_x_96, // lower_tick
            sqrt_ratio_b_x_96, // upper_tick
            amount_0,          // amount_0
            amount_1,          // amount_1
        )?
        .to_i128()
        .map_or_else(|| Err(Error::LiquidityAmountTooWide), Ok)?;

        if giving {
            // If we're giving, then we need to take from the delta.
            delta = -delta;
        }

        #[cfg(feature = "testing-dbg")]
        dbg!((
            "inside adjust_position",
            current_test!(),
            sqrt_ratio_x_96.to_string(),
            sqrt_ratio_a_x_96.to_string(),
            sqrt_ratio_b_x_96.to_string(),
            amount_0.to_string(),
            amount_1.to_string(),
            delta
        ));

        // [update_position] should also ensure that we don't do this on a pool that's not currently
        // running

        self.update_position(id, delta)
    }
```

In the above function at LOC-265, we have:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L265>

```rust
let sqrt_ratio_x_96 = tick_math::get_sqrt_ratio_at_tick(self.get_cur_tick().as_i32())?;
```

Instead of:

```rust
let sqrt_price_x_96 = self.sqrt_price.get();
```

This passes not the current price but the price of the current tick to the `get_liquidity_for_amounts()` function.

### Proof of Concept

The following is a step-by-step PoC that explains the issue in detail. Let's say there exists a pool with the following configuration:

```
token0 = X
token1 = FUSDC

There are many available positions; one of them with tick range [0, 5].

Current price of the pool lies between ticks 0 and 1 and is equals to 1.00005
```

The current tick of a pool is determined by:

*Note: please see scenario in warden's [original submission](https://github.com/code-423n4/2024-08-superposition-findings/issues/77)*.

Now, a user A, owner of the position stated above, calls the function:

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/sol/SeawaterAMM.sol#L464>

```solidity
    function incrPositionC3AC7CAA(
        address /* pool */,
        uint256 /* id */,
        uint256 /* amount0Min */,
        uint256 /* amount1Min */,
        uint256 /* amount0Desired */,
        uint256 /* amount1Desired */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorUpdatePosition());
    }
```

Ultimately, the `adjust_position()` in pool.rs is called. In this function, at LOC-265, the following is set:

```rust
let sqrt_ratio_x_96 = tick_math::get_sqrt_ratio_at_tick(self.get_cur_tick().as_i32())?;
```

This means that `sqrt_ratio_x_96` would have 1 (or `2^96`) as the `curr_tick` is 0. Now, `get_liquidity_for_amounts()` function is called:

```rust
pub fn get_liquidity_for_amounts(
    sqrt_ratio_x_96: U256,
    mut sqrt_ratio_a_x_96: U256,
    mut sqrt_ratio_b_x_96: U256,
    amount_0: U256,
    amount_1: U256,
) -> Result<u128, Error> {
    if sqrt_ratio_a_x_96 > sqrt_ratio_b_x_96 {
        (sqrt_ratio_a_x_96, sqrt_ratio_b_x_96) = (sqrt_ratio_b_x_96, sqrt_ratio_a_x_96)
    };

    let delta = if sqrt_ratio_x_96 <= sqrt_ratio_a_x_96 {
        get_liquidity_for_amount_0(sqrt_ratio_a_x_96, sqrt_ratio_b_x_96, amount_0)?
    } else if sqrt_ratio_x_96 < sqrt_ratio_b_x_96 {
        let liq0 = get_liquidity_for_amount_0(sqrt_ratio_x_96, sqrt_ratio_b_x_96, amount_0)?;
        let liq1 = get_liquidity_for_amount_1(sqrt_ratio_a_x_96, sqrt_ratio_x_96, amount_1)?;
        if liq0 > liq1 {
            liq1
        } else {
            liq0
        }
    } else {
        get_liquidity_for_amount_1(sqrt_ratio_a_x_96, sqrt_ratio_b_x_96, amount_1)?
    };

    Ok(delta)
}
```

This function checks at LOC-312 that:

```rust
if sqrt_ratio_x_96 <= sqrt_ratio_a_x_96
```

and calls:

```rust
get_liquidity_for_amount_0(sqrt_ratio_a_x_96, sqrt_ratio_b_x_96, amount_0)?
```

This is wrong as the current price of the pool (`= 1.00005`) is in the price range of the position (`[1, (1.0001)^5]`).

Basically, the main liquidity formula used by the protocol currently is:

*Note: please see scenario in warden's [original submission](https://github.com/code-423n4/2024-08-superposition-findings/issues/77)*.

The calculation is also wrong. Let's assume that A calls the function with:

```python
        amount0Min = 95% of amount0Desired
        amount0Desired = 1000 (assume decimal included)
```

The present calculation would result in an `amount0` that would be `~899.98` or 900 which is 90% of `amount0Desired` and thus, is less than `amount0Min`. Therefore, this transaction would revert.

### Severity

The protocol mentions "We should follow Uniswap V3's math faithfully" as one of its core invariants. This must not break. However, as this report explains, this invariant stands broken.

If the `amount0Desired` and `amount0Min` (also applicable to `amount1`) are very close to each other, then the transaction to `incrPositionC3AC7CAA()` function reverts. So, the severity is High.

### Tools Used

Desmos scientific calculator.

### Recommended Mitigation Steps

Replace the following in the `adjust_position()` function below:

```diff
    pub fn adjust_position(
        &mut self,
        id: U256,
        amount_0: U256,
        amount_1: U256,
        giving: bool,
    ) -> Result<(I256, I256), Revert> {
        // calculate the delta using the amounts that we have here, guaranteeing
        // that we don't dip below the amount that's supplied as the minimum.

        let position = self.positions.positions.get(id);

-       let sqrt_ratio_x_96 = tick_math::get_sqrt_ratio_at_tick(self.get_cur_tick().as_i32())?;
+       let sqrt_ratio_x_96 = self.sqrt_price.get();
        let sqrt_ratio_a_x_96 = tick_math::get_sqrt_ratio_at_tick(position.lower.get().as_i32())?;
        let sqrt_ratio_b_x_96 = tick_math::get_sqrt_ratio_at_tick(position.upper.get().as_i32())?;

        let mut delta = sqrt_price_math::get_liquidity_for_amounts(
            sqrt_ratio_x_96,   // cur_tick
            sqrt_ratio_a_x_96, // lower_tick
            sqrt_ratio_b_x_96, // upper_tick
            amount_0,          // amount_0
            amount_1,          // amount_1
        )?
        .to_i128()
        .map_or_else(|| Err(Error::LiquidityAmountTooWide), Ok)?;

        if giving {
            // If we're giving, then we need to take from the delta.
            delta = -delta;
        }

        #[cfg(feature = "testing-dbg")]
        dbg!((
            "inside adjust_position",
            current_test!(),
            sqrt_ratio_x_96.to_string(),
            sqrt_ratio_a_x_96.to_string(),
            sqrt_ratio_b_x_96.to_string(),
            amount_0.to_string(),
            amount_1.to_string(),
            delta
        ));

        // [update_position] should also ensure that we don't do this on a pool that's not currently
        // running

        self.update_position(id, delta)
    }
```

### Assessed type

Math

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#issuecomment-2369635535):**
 > While the submission is elaborate and goes into great detail, I do not believe that a tangible issue can manifest from calculating the square root price from the current tick as it should match the current price whenever this particular function is invoked. As such, I would advise a PoC to be introduced for this particular submission.

**[prapandey031 (warden) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#issuecomment-2374282814):**
 > @0xsomeone - The issue is not a mere use of the price of `current_tick` instead of the `current_sqrt_price`. Rather, this report describes how the Superposition protocol uses the wrong Uniswap v3 liquidity math formula.
> 
> ### Difference between `current_sqrt_price` and price of the `current_tick`
> 
> Uniswap v3 wrote a [blog](https://blog.uniswap.org/uniswap-v3-math-primer#how-does-tick-and-tick-spacing-relate-to-sqrtpricex96) describing the relationship between `current_tick`, `current_tick_price`, and `current_sqrt_price`. The blog states that:
> > This explains why using ticks can be less precise than `sqrtPriceX96` in Uniswap v3.
> 
> > Just like ticks can be in between initialized ticks, ticks can also be in between integers as well! The protocol itself reports the floor `⌊ic⌋` of the current tick, which the `sqrtPriceX96` retains.
> 
> To simplify, getting the price of the `current_tick` would **not** be equal to getting the `current_sqrt_price`, as Uniswap v3 stores the `current_tick` as the floor of the tick derived through the `current_sqrt_price`:
> 
> *Note: please see scenario in warden's [original comment](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#issuecomment-2374282814).*
>
> The above is equation 6.8 from Uniswap v3 whitepaper. The example in the blog makes it clear:
> 
> ```python
> current_sqrt_price = 649004842.70137
> price using current_tick = 648962487.5642413
> ```
> 
> ### Mathematical PoC for deviation from Uniswap v3 math
> 
> *Note: please see scenario in warden's [original comment](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#issuecomment-2374282814).*
> 
> ### Result
> 
> Both parts lead to the wrong calculation of `Delta Liquidity`. Finally, this results in the wrong calculation of `amount_0` and `amount_1` when `adjust_position()` function calls `update_position(&mut self, id: U256, delta: i128)` function with the wrongly calculated `delta`:
> 
> https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L299
> 
> ```rust
>         self.update_position(id, delta)
> ```
> 
> The root cause of the issue is the use of price of the `current_tick` instead of the `current_sqrt_price`:
> 
> https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L265
> 
> ```rust
>         let sqrt_ratio_x_96 = tick_math::get_sqrt_ratio_at_tick(self.get_cur_tick().as_i32())?;
> ```
> 
> This should be replaced with:
> 
> ```rust
>         let sqrt_ratio_x_96 = self.sqrt_price.get();
> ```
> 
> With this fix, the correct liquidity formulas are used for both parts. This issue is valid as the sponsor has mentioned faithful use of Uniswap v3 math as a core invariant in the Readme of the audit. This report successfully shows that this core invariant stands broken.

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#issuecomment-2392109425):**
 > @prapandey031 - I greatly appreciate the in-depth mathematical analysis of the issue; however, a simple deviation of the mathematical formulae implemented by Uniswap V3 is not adequate to consider this an HM risk submission. 
> 
> I would advise you to quantify the precise error that would result from this flooring mechanism of the tick, as well as produce a PoC that demonstrates the issue (i.e., an execution of the same operations in Uniswap V3 and the SuperPosition system) to illustrate the vulnerability in practice. 
> 
> While the error is clear, we need to have a quantifiable impact to assess it as an HM risk.

**[prapandey031 (warden) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#issuecomment-2394092740):**
 > @0xsomeone - I would quantify the funds that Superposition looses due to the explained error as well as detail other impacts.
> 
> Below I present calculation PoCs to quantify the impact. I break the complete PoC into 2 parts corresponding to the 2 parts in my previous response.
> 
> I build this response on top of my previous response. In my previous response, I proved that Superposition uses wrong liquidity equations. I did this using the in-scope code snippets of Superposition and Uniswapv3 math equations. In this response I calculate values based on the correct and wrong equations to quantify the impact.
> 
> *Note: please see scenario in warden's [original comment](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#issuecomment-2394092740).*
>
> ***
>
> To confirm that the Uniswapv3 really uses the equations that I state above (although whatever equations stated above can be found in Uniswapv3 whitepaper; I took all of them from there) I provide the relevant code snippets from Uniswapv3-periphery repo:
> 
> `addLiquidity(AddLiquidityParams memory params)` which is similar to `adjust_position()` in Superposition:
> 
> ```solidity
>     /// @notice Add liquidity to an initialized pool
>     function addLiquidity(AddLiquidityParams memory params)
>         internal
>         returns (
>             uint128 liquidity,
>             uint256 amount0,
>             uint256 amount1,
>             IUniswapV3Pool pool
>         )
>     {
>         PoolAddress.PoolKey memory poolKey =
>             PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee});
> 
>         pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
> 
>         // compute the liquidity amount
>         {
> >           (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
>             uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
>             uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);
> 
>             liquidity = LiquidityAmounts.getLiquidityForAmounts(
>                 sqrtPriceX96,
>                 sqrtRatioAX96,
>                 sqrtRatioBX96,
>                 params.amount0Desired,
>                 params.amount1Desired
>             );
>         }
> 
>         (amount0, amount1) = pool.mint(
>             params.recipient,
>             params.tickLower,
>             params.tickUpper,
>             liquidity,
>             abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
>         );
> 
>         require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Price slippage check');
>     }
> }
> ```
> 
> Notice how Uniswapv3 uses `current_sqrt_price` instead of price of `current_tick` at marked (`>`) LOC above. This is the fix that I proposed in the original report.
> 
> `getLiquidityForAmounts()` which is similar to `get_liquidity_for_amounts()` in Superposition:
> 
> ```solidity
>     function getLiquidityForAmounts(
>         uint160 sqrtRatioX96,
>         uint160 sqrtRatioAX96,
>         uint160 sqrtRatioBX96,
>         uint256 amount0,
>         uint256 amount1
>     ) internal pure returns (uint128 liquidity) {
>         if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
> 
>         if (sqrtRatioX96 <= sqrtRatioAX96) {
>             liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
>         } else if (sqrtRatioX96 < sqrtRatioBX96) {
>             uint128 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
>             uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);
> 
>             liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
>         } else {
>             liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
>         }
>     }
> ```

**[0xsomeone (judge) decreased severity to Medium and commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#issuecomment-2396717333):**
 > @prapandey031 - thank you for diving deeper into this particular submission! The original submission's impact indicated that transactions would fail when the minimum amounts are close to the expected amounts; however, your latest feedback indicates that actual fund loss would occur.
> 
> Given that the submission must be judged on its original merits and its validity has been demonstrated, I will award this as a medium-severity submission that would cause a portion of the protocol to become inaccessible versus resulting in fund loss, as this is an aspect not described in the original report.

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/77#event-14702625260)** 

***

## [[M-04] Lp's liquidity may be lost if re-org happens](https://github.com/code-423n4/2024-08-superposition-findings/issues/62)
*Submitted by [zhaojohnson](https://github.com/code-423n4/2024-08-superposition-findings/issues/62)*

LP holders will remove liquidity and then burn their liquidity position. If re-org happens, malicious users can manipulate the pool's price to cause user's removing liquidity revert. Then LP holders' position will be burned and liquidity will be locked in contract.

### Proof of Concept

In lib.rs, users can burn their position. From this function's comment, `Calling this function leaves any liquidity or fees left in the position inaccessible.`, it's user's responsibility to remove their liquidity before they burn their position.
The problem is that even if users follow this rule, remove liquidity at first, and then burn their position, users may still lose their funds.

Re-org is one common scenario in Arbitrum. When re-org happens, some transactions will be re-ordered and re-executed.
For example:

1. Alice removes her liquidity with one slippage control parameter.
2. Alice burns her position.
3. Re-org happens. Bob monitors the re-org and try to do some swap in pool to change pool's price and tick.
4. Alice removing liquidity transaction will be executed and reverted because Bob changes current pool's price and Alice's slippage condition will not be matched.
5. Alice's burning position can still be executed successfully.
6. Alice will lose her funds.

```javascript
    pub fn burn_position_AE401070(&mut self, id: U256) -> Result<(), Revert> {
        let owner = msg::sender();
        // Get this NFT(position)'s owner to make sure that the caller owns this position.
        assert_eq_or!(
            self.position_owners.get(id),
            owner,
            Error::PositionOwnerOnly
        );

        self.remove_position(owner, id);

        #[cfg(feature = "log-events")]
        evm::log(events::BurnPosition { owner, id });

        Ok(())
    }
```

### Recommended Mitigation Steps

Add some more check on `burn_position_AE401070()`, revert if there are some left liquidity.

### Assessed type

Context

**[af-afk (Superposition) confirmed and commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/62#issuecomment-2354621981):**
 > We're going to resolve this by deleting the burn position feature.

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/62#issuecomment-2369611544):**
 > The Warden has identified a mechanism in the Seawater system that can become harmful if a re-organization occurs, leading to a total loss of the funds associated with the position.
> 
> I believe a medium risk severity rating is appropriate given the likelihood of a re-organization simultaneously occurring with the sequence of events outlined (i.e., different blocks that ended up being re-ordered executing the actions outlined) is low.

**[Silvermist (warden) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/62#issuecomment-2373364295):**
 > Arbitrum's docs [states](https://docs.arbitrum.io/learn-more/faq#:~:text=Nope%3B%20once%20an%20Arbitrum%20transaction%20is%20included%20on%20L1%2C%20there%20is%20no%20way%20it%20can%20be%20reorged) that a transaction can't be re-orged, so this should be invalid.

**[Blckhv (warden) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/62#issuecomment-2373404458):**
 > Yeah, there are no re-orgs in Arbitrum - https://abarbatei.xyz/blockchain-reorgs-for-managers-and-auditors#heading-metrics-for-protocols-and-auditors.

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/62#issuecomment-2396699056):**
 > @Silvermist and @Blckhv - The documentation referenced states that if the L1 re-orgs, then the Arbitrum transactions will re-org as well. This is also [referenced in the glossary itself](https://docs.arbitrum.io/intro/glossary#reorg). 
> 
> The link referenced by @Blckhv also does not say that "re-orgs are not possible", simply that they have not been observed yet. As such, the original ruling of the submission stands.

*Note: For full discussion, see [here](https://github.com/code-423n4/2024-08-superposition-findings/issues/62).*

***

## [[M-05] When performing `swap` and the swap position does not cover `swap amount`, the base price of `sqrt_price` is set incorrectly](https://github.com/code-423n4/2024-08-superposition-findings/issues/58)
*Submitted by [13u9](https://github.com/code-423n4/2024-08-superposition-findings/issues/58)*

When performing a swap, a position is searched and if a position with an appropriate price exists, the swap is performed using the token amount of that position. If the positions in the current pool do not cover the swap amount requested by the user, the value of `sqrt_price` will not be set accurately, which may cause confusion when the next user swaps.

### Proof of Concept

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L303-L535>

When a swap is performed, the 'swap' function in pools.rs is triggered.

```
    pub fn swap(
            &mut self,
            zero_for_one: bool,
            amount: I256,
            mut price_limit: U256,
        ) -> Result<(I256, I256, i32), Revert> {
            assert_or!(self.enabled.get(), Error::PoolDisabled);

            ''' skip '''
```

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L378-L492>

```
            while !state.amount_remaining.is_zero() && state.price != price_limit {
                iters += 1;
                debug_assert!(iters < 500);
                ''' skip '''
```

When performing a swap, the while statement above iterates through the position that matches the tick and searches for it. If a matching position exists, the token of that position is processed and the state is updated.

The while statement will continue until the `swap amount` requested by the user becomes `0` or the `price` reaches the `price_limit` requested by the user.

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L496>

```
            self.sqrt_price.set(state.price);
```

After the while loop is finished, the final `sqrt_price` value is updated to the `state.price` value.

If the `swap amount` within the `price_limit` range requested by the user is not covered by the positions in the pool, the `position price` will be set to the `price_limit` value set by the user, not the `position price` that was actually `swapped` last; which will be different from the last swapped price, and the user requesting the next swap may be confused about the `swap price`.

**Scenario:**

1. Assume that the following positions are currently formed in the pool:

```
    pool1 state:
    lower = 1000
    upper = 2000
    amount = 20

    pool2 state:
    lower = 3000
    upper = 4000
    amount = 20
```

2. Assume that the user sets `swap amount` to `100` and `price_limit` to `10000` and requests a swap.

3. When the swap is in progress, it searches for a pool that can be swapped and processes `amount 20` of `pool1` and `amount 30` of `pool2` to swap a total of 50 tokens. At this time, the position of the pool within the `price_limit` set by the user cannot process the `swap amount` requested by the user, so the while statement is performed until `state.price == price_limit`, and finally the `sqrt_price` value is set to the `state.price` value. (`state.price is equal to price_limit`)

4. After the swap routine is finished, the reference `swap price` will be set to `10000`, which is the `price_limit` set by the user, and not the `swap price` of `pool2` where the last swap was done.

5. Users requesting the next swap may experience confusion when processing the swap because the swap base price starts at the price of the `price_limit set by the previous user`, rather than the `base price` of the `pool where the last swap was made`.

### Test Code

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L312-L331>

```
            match zero_for_one {
                true => {
                    if price_limit == U256::MAX {
                        price_limit = tick_math::MIN_SQRT_RATIO + U256::one();
                    }
                    if price_limit >= self.sqrt_price.get() || price_limit <= tick_math::MIN_SQRT_RATIO
                    {
                        Err(Error::PriceLimitTooLow)?;
                    }
                }
                false => {
                    if price_limit == U256::MAX {
                        price_limit = tick_math::MAX_SQRT_RATIO - U256::one();
                    }
                    if price_limit <= self.sqrt_price.get() || price_limit >= tick_math::MAX_SQRT_RATIO
                    {
                        Err(Error::PriceLimitTooHigh)?;
                    }
                }
            };
```

Test Code POC is the code that sets `zero_for_one` to `true` and `price_limit` to `U256::MAX` and returns an error return in the above conditional statement when the second swap is performed.

### Write Test code

Write Test Code in `test/lib.rs` file:

<details>

```
#[test]
fn test_poc1() -> Result<(), Vec<u8>> {
    test_utils::with_storage::<_, Pools, _>(
        Some(address!("feb6034fc7df27df18a3a6bad5fb94c0d3dcb6d5").into_array()),
        None, // slots map
        None, // caller erc20 balances
        None, // amm erc20 balances
        |contract| {
            // Create the storage
            contract.seawater_admin.set(msg::sender());
            let token_addr = address!("97392C28f02AF38ac2aC41AF61297FA2b269C3DE");

            // First, we set up the pool.
            contract.create_pool_D650_E2_D0(
                token_addr,
                test_utils::encode_sqrt_price(100, 1), // the price
                0,
                1,
                100000000000,
            )?;

            contract.enable_pool_579_D_A658(token_addr, true)?;

            let lower_tick = 39122;
            let upper_tick = 50108;
            let liquidity_delta = 20000;

            // create first position
            contract.mint_position_B_C5_B086_D(token_addr, lower_tick, upper_tick)?;
            let position_id = contract
                .next_position_id
                .clone()
                .checked_sub(U256::one())
                .unwrap();

            // set position liquidity
            contract.update_position_C_7_F_1_F_740(token_addr, position_id, liquidity_delta)?;


            let (amount_out_0, amount_out_1) = contract.swap_904369_B_E(
                token_addr,
                true,
                I256::try_from(100000_i32).unwrap(),
                U256::MAX,
            )?;

            // At this time, the value of ```self.sqrt_price``` is ```tick_math::MIN_SQRT_RATIO```


            // create second position
            // Set lower_tick to the last swapped tick
            let lower_tick = -887272;
            let upper_tick = 887272;
            let liquidity_delta = 20000000;
            contract.mint_position_B_C5_B086_D(token_addr, lower_tick, upper_tick)?;
            let id = U256::try_from(1).unwrap();
            // set enough liquidity
            contract.update_position_C_7_F_1_F_740(token_addr, id, liquidity_delta)?;

            // try second swap
            let (amount_out_0, amount_out_1) = contract.swap_904369_B_E(
                token_addr,
                true,
                I256::try_from(100_i32).unwrap(),
                U256::MAX,
            )?;

            Ok(())
        },
    )
}
```

</details>

Add `println!` code line and remove `debugassert statement` on `swap` function in `src/pool.rs`:

```
        pub fn swap(
            &mut self,
            zero_for_one: bool,
            amount: I256,
            mut price_limit: U256,
        ) -> Result<(I256, I256, i32), Revert> {
            assert_or!(self.enabled.get(), Error::PoolDisabled);
            println!("self.sqrt_price: {}", self.sqrt_price.get()); // added
```
```
            while !state.amount_remaining.is_zero() && state.price != price_limit {
                iters += 1;
                // debug_assert!(iters < 500);
```

**Run Test:**

```
    cargo test test_poc1 --package seawater --features testing -- --nocapture
```

**Result:**

```
    running 1 test
    self.sqrt_price: 792281625142643375935439503360
    self.sqrt_price: 4295128740
    Error: [80, 114, 105, 99, 101, 32, 108, 105, 109, 105, 116, 32, 116, 111, 111, 32, 108, 111, 119]
    test test_poc1 ... FAILED

    failures:

    failures:
        test_poc1

    test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 16 filtered out; finished in 0.14s

    error: test failed, to rerun pass `-p seawater --test lib`
```

When requesting a second swap, you can see that an error return occurs because `sqrt_price` is set to the `price_limit` set in the previous swap even though the position existed.

### Tools Used

Visual Studio Code

### Recommended Mitigation Steps

Modify to allow setting the value to the price of the last swapped position even if the position amount is insufficient.

```
    @@ -375,9 +375,10 @@ impl StoragePool {
             // continue swapping while there's tokens left to swap
             // and we haven't reached the price limit
             let mut iters = 0;
    +        let mut last_valid_price = state.price;
             while !state.amount_remaining.is_zero() && state.price != price_limit {
                 iters += 1;
    -            debug_assert!(iters < 500);
    +            // debug_assert!(iters < 500);

                 let step_initial_price = state.price;

    @@ -479,6 +480,7 @@ impl StoragePool {
                         };

                         state.liquidity = liquidity_math::add_delta(state.liquidity, liquidity_net)?;
    +                    last_valid_price = state.price;
                     }

                     state.tick = match zero_for_one {
    @@ -493,7 +495,8 @@ impl StoragePool {

             // write state
             // update price and tick
    -        self.sqrt_price.set(state.price);
    +        self.sqrt_price.set(if state.price == price_limit { last_valid_price } else { state.price });
    +
             if state.tick != self.cur_tick.get().sys() {
                 self.cur_tick.set(I32::unchecked_from(state.tick));
             }
```

**Mitigation Test Result:**

Test Code is same above Test Code

```
         Running tests/lib.rs (target/debug/deps/lib-28fa4ebf2403ec3f)

    running 1 test
    self.sqrt_price: 792281625142643375935439503360
    self.sqrt_price: 560222498985353939371108591955
    test test_poc1 ... ok

    test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 16 filtered out; finished in 0.14s

         Running tests/pools.rs (target/debug/deps/pools-a3343d45185ff606)
```

Unlike before, it is set to the tick where the last swap occurred.

### Assessed type

Loop

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/58#event-14300399453)**

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/58#issuecomment-2369615846):**
 > The Warden has correctly identified that the configuration of the square root price of the pool will be incorrect in case the price limit configured by the user has been achieved as the state's price is updated on each search iteration rather than being updated on the last valid swapped price.
> 
> I believe a medium-risk severity rating is appropriate given that a user can simply swap the price back down to the actual price of the AMM and no active harm may occur to the liquidity within the pool or its assets.

***

## [[M-06] `decrPosition09293696` will not work due to incorrect function signature](https://github.com/code-423n4/2024-08-superposition-findings/issues/57)
*Submitted by [ZanyBonzy](https://github.com/code-423n4/2024-08-superposition-findings/issues/57), also found by [shaflow2](https://github.com/code-423n4/2024-08-superposition-findings/issues/172) and [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/33)*

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L476-L485>

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L938>

### Impact

`decrPosition09293696` will not work, breaking SeawaterAMM.sol's functionality to decrease position.

### Proof of Concept

SeaWaterAMM.sol holds the `decrPosition09293696` which allows for refreshing a position's fees and takes liqiudity from it.

The function takes in various parameters but is missing the pool address parameter.

```solidity
    function decrPosition09293696(
        uint256 /* id */,
        uint256 /* amount0Min */,
        uint256 /* amount1Min */,
        uint256 /* amount0Max */,
        uint256 /* amount1Max */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorUpdatePosition());
    }
```

As can be seen from the `decr_position_09293696` function, the pool address must be declared from which liquidity can be taken from its positions.

```rust
    pub fn decr_position_09293696(
        &mut self,
        pool: Address, //@audit
        id: U256,
        amount_0_min: U256,
        amount_1_min: U256,
        amount_0_max: U256,
        amount_1_max: U256,
    ) -> Result<(U256, U256), Revert> {
//...
    }
}
```

Calls to the function will always fail, as a result, accessing the `decrPosition09293696` function through SeawaterAMM.sol will always fail.

### Recommended Mitigation Steps

Introduce the pool address parameter:

```diff
    function decrPosition09293696(
+       address /* pool */,
        uint256 /* id */,
        uint256 /* amount0Min */,
        uint256 /* amount1Min */,
        uint256 /* amount0Max */,
        uint256 /* amount1Max */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorUpdatePosition());
    }
```

### Assessed type

Context

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/57#event-14285063573)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/57#issuecomment-2369616609):**
 > The Warden has correctly identified that the function definitions of the Solidity and Stylus contracts differ, resulting in the relevant functionality of the system being inaccessible.
> 
> I believe a medium-risk rating is appropriate for this vulnerability given that it is possible to interact with positions via the adjust position function and thus the functionality is simply inaccessible via the decrease position pathway rather than being inaccessible completely.

***

## [[M-07] Unintended under/overflow of the amount already swapped in/out due to unmatching logic](https://github.com/code-423n4/2024-08-superposition-findings/issues/50)
*Submitted by [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/50)*

A possible wrong amount of the amount already swapped in/out of the input/output asset of a swap due to an unintended under/overflow.

### Proof of Concept

In Rust release mode, the `-` and `+` operations will **not** revert when an underflow/overflow occurs.

As such, the amount can under/overflow in the `while` loop:

```rust
    match exact_in {
        true => { 
            state.amount_remaining -=
                I256::unchecked_from(step_amount_in + step_fee_amount);
->          state.amount_calculated -= I256::unchecked_from(step_amount_out); //@audit this can underflow with -=
        }
        false => {
            state.amount_remaining += I256::unchecked_from(step_amount_out);
->          state.amount_calculated += //@audit this can overflow with +=
                I256::unchecked_from(step_amount_in + step_fee_amount); 
        }
    }
```

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/pool.rs#L439>

The issue is that these are not meant to under/overflow as seen in the original Uniswap logic, as they use SafeMath:

```solidity
    if (exactInput) {
        state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
->      state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
    } else {
        state.amountSpecifiedRemaining += step.amountOut.toInt256();
->      state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
    }
```

<https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/UniswapV3Pool.sol#L673-L679>

Uniswap tests that `state.amountSpecifiedRemaining > step.amountIn + step.feeAmount` and that's why the operation is safe to use unchecked, but this is not the case with the second one, which must be checked:

<https://github.com/Uniswap/v3-core/blob/0.8/contracts/UniswapV3Pool.sol#L681-L685>

### Recommended Mitigation Steps

Consider using `checked_sub` instead of `-` (and `checked_add` instead of `+`):

```diff
    match exact_in {
        true => { 
            state.amount_remaining -=
                I256::unchecked_from(step_amount_in + step_fee_amount);
-           state.amount_calculated -= I256::unchecked_from(step_amount_out);
+           state.amount_calculated = state.amount_calculated.checked_sub(I256::unchecked_from(step_amount_out));
        }
        false => {
            state.amount_remaining += I256::unchecked_from(step_amount_out);
-           state.amount_calculated +=
-               I256::unchecked_from(step_amount_in + step_fee_amount);
+           state.amount_calculated = state.amount_calculated.checked_add(
+               I256::unchecked_from(step_amount_in + step_fee_amount));
        }
    }
```

### Assessed type

Uniswap

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/50#event-14285134068)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/50#issuecomment-2369626597):**
 > The submission details that the swap step calculations will perform an insecure subtraction or addition which might result in uncaught overflows/underflows occurring that should normally be prevented.
> 
> While I am inclined to retain a medium-risk severity rating for this submission **for now**, I would advise the Warden to substantiate their claim via a PoC that demonstrates the vulnerability in practice. If no PoC is provided, I will re-evaluate after PJQA and *potentially* downgrade to QA (L) due to insufficient proof.

***

## [[M-08] Users can't remove liquidity while a pool is disabled](https://github.com/code-423n4/2024-08-superposition-findings/issues/31)
*Submitted by [Silvermist](https://github.com/code-423n4/2024-08-superposition-findings/issues/31), also found by [zhaojohnson](https://github.com/code-423n4/2024-08-superposition-findings/issues/154), [nslavchev](https://github.com/code-423n4/2024-08-superposition-findings/issues/123), [Testerbot](https://github.com/code-423n4/2024-08-superposition-findings/issues/102), [devival](https://github.com/code-423n4/2024-08-superposition-findings/issues/83), and [prapandey031](https://github.com/code-423n4/2024-08-superposition-findings/issues/175)*

There is a functionality for disabling a pool in case of unforeseen circumstances or if a problem occurs. While the pool is disabled the users should not be able to do certain actions but removing their liquidity should not be one of them. When a problem occurs in the pool, users should be able to remove their liquidity, as it may be at risk and they may lose their money. The problem is there is a check that does not allow them to do it.

### Proof of Concept

`update_position_internal` has a [comment](https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L687C25-L687C83) that states "Requires the pool to be enabled unless removing liquidity.", meaning that there should be a check for the pool status only when liquidity is added and the users should be allowed to remove their liquidity if the pool is not active.

But `update_position_internal` calls `update_position` that is used to add or remove liquidity from a position and the function has this check:

```js
        assert_or!(self.enabled.get(), Error::PoolDisabled);
```

The check above prevents the function from being called when the pool is disabled, which is understandable in case users want to add liquidity to the pool when there is a problem.

However, users don't want their money to be at risk and they would want to remove their funds but they can't because of that check.

### Recommended Mitigation Steps

If the passed `delta` is negative, it means the user is removing liquidity, so check the pool's status only when the `delta` is positive.

### Assessed type

Access Control

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/31#event-14300539250)** 

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/31#issuecomment-2369648185):**
 > The submission and its duplicates have correctly identified that liquidity withdrawals are disallowed when the pool is paused despite what the code's documentation indicates.
> 
> I believe a medium-risk severity rating is appropriate given that important functionality of the protocol is inaccessible in an emergency scenario when it should be accessible.

***

## [[M-09] `swap_2` implementation will randomly revert due to improper check, root cause for failed test `ethers_suite_uniswap_orchestrated_uniswap_two`](https://github.com/code-423n4/2024-08-superposition-findings/issues/30)
*Submitted by [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/30), also found by [pipidu83](https://github.com/code-423n4/2024-08-superposition-findings/issues/147), [prapandey031](https://github.com/code-423n4/2024-08-superposition-findings/issues/75), and [Silvermist](https://github.com/code-423n4/2024-08-superposition-findings/issues/34)*

`swap_2` implementation will randomly revert due to improper check, root cause for failed test [`ethers_suite_uniswap_orchestrated_uniswap_two`](https://github.com/code-423n4/2024-08-superposition?tab=readme-ov-file#running-tests).

### Proof of Concept

The audit readme listed an unsolved failed test `ethers_suite_uniswap_orchestrated_uniswap_two()`. The failed test is due to an improper check in `swap_2_internal()`, which sometimes causes a valid `swap_2` to revert.

We see that in `swap_2_internal`, `interim_usdc_out` is required to equal `interim_usdc_in`. `interim_usdc_out` is the `fusdc` swapped out in 1st swap. `interim_usdc_in` is the actual `fusdc` swapped in 2nd swap. In any swap, not all user input amount has to be used to achieve a desirable output. Especially in uniswapV3 swap logic, [`amount_remaining` can be greater than 0](https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/pool.rs#L378), which means not all input tokens are used.

```rust
//pkg/seawater/src/lib.rs
    fn swap_2_internal(
        pools: &mut Pools,
        from: Address,
        to: Address,
        amount: U256,
        min_out: U256,
    ) -> Result<(U256, U256, U256, I256, i32, i32), Revert> {
...
        // swap in -> usdc
        let (amount_in, interim_usdc_out, final_tick_in) = pools.pools.setter(from).swap(
            true,
            amount,
            // swap with no price limit, since we use min_out instead
            tick_math::MIN_SQRT_RATIO + U256::one(),
        )?;
...
        // swap usdc -> out
        let (amount_out, interim_usdc_in, final_tick_out) = pools.pools.setter(to).swap(
            false,
            interim_usdc_out,
            tick_math::MAX_SQRT_RATIO - U256::one(),
        )?;
...
|>      assert_eq_or!(interim_usdc_out, interim_usdc_in, Error::InterimSwapNotEq);
...
```

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L241

The equality check will cause revert when 2nd swap runs out of liquidity but still satisfies the user's `min_out`. A valid swap can be reverted.

Test `ethers_suite_uniswap_orchestrated_uniswap_two()` analysis:
When running the test, the output error byte array `[73, 110, 116, 101, 114, 110, 97, 108, 32, 115, 119, 97, 112, 32, 97, 109, 111, 117, 110, 116, 115, 32, 110, 111, 116, 32, 109, 97, 116, 99, 104, 101, 100]` decodes(ASII) into `Internal swap amounts not matched`, corresponding to `Error::InterimSwapNotEq`. This custom error is only used in `swap_2_internal`.

```
thread 'ethers_suite_orchestrated_uniswap_two' panicked at seawater/tests/lib.rs:783:18:
called `Result::unwrap()` on an `Err` value: [73, 110, 116, 101, 114, 110, 97, 108, 32, 115, 119, 97, 112, 32, 97, 109, 111, 117, 110, 116, 115, 32, 110, 111, 116, 32, 109, 97, 116, 99, 104, 101, 100]
```

I added a unit test to break down the failed reason `ethers_suite_orchestrated_uniswap_two_breakdown`:

```rust
//pkg/seawater/tests/lib.rs
#[test]
fn ethers_suite_orchestrated_uniswap_two_breakdown() {
    test_utils::with_storage::<_, Pools, _>(
        Some(address!("3f1Eae7D46d88F08fc2F8ed27FCb2AB183EB2d0E").into_array()), // sender
        None,
        None,
        None,
        |contract| {
            let token0 = address!("9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0");
            let token1 = address!("9fE46736679d2D9a65F0992F2272dE9f3c7fa6e1");
            contract
                .ctor(msg::sender(), Address::ZERO, Address::ZERO)
                .unwrap();
            contract
                .create_pool_D650_E2_D0(
                    token0,
                    U256::from_limbs([0, 42949672960, 0, 0]), //792281625142643375935439503360
                    500,                                      // fee
                    10,                                       // tick spacing
                    u128::MAX,
                )
                .unwrap();
            contract
                .create_pool_D650_E2_D0(
                    token1,
                    U256::from_limbs([0, 42949672960, 0, 0]), //792281625142643375935439503360
                    500,                                      // fee
                    10,                                       // tick spacing
                    u128::MAX,
                )
                .unwrap();
            contract.enable_pool_579_D_A658(token0, true).unwrap();
            contract.enable_pool_579_D_A658(token1, true).unwrap();
            contract
                .mint_position_B_C5_B086_D(token0, 39120, 50100)
                .unwrap();
            contract
                .mint_position_B_C5_B086_D(token1, 39120, 50100)
                .unwrap();
            let id = U256::ZERO;
            let (amount_0_in, fusdc_0_in) = contract
                .update_position_C_7_F_1_F_740(token0, id, 20000)
                .unwrap();
            println!("amount_0_in: {amount_0_in}, fusdc_0_in: {fusdc_0_in}");
            let (amount_1_in, fusdc_1_in) = contract
                .update_position_C_7_F_1_F_740(token1, U256::one(), 20000)
                .unwrap();
            println!("amount_1_in: {amount_1_in}, fusdc_1_in: {fusdc_1_in}");
            //breakdown: step1 token0 -> fusdc
            let (amount_out_0, fusdc_out_0) = contract
                .swap_904369_B_E(token0, true, I256::try_from(1000_i32).unwrap(), U256::MAX)
                .unwrap();
            println!("amount_out_0: {amount_out_0}, fusdc_out_0: {fusdc_out_0}");
            //breakdown: step2 fusdc -> token1
            let (amount_out_1, fusdc_out_1) = contract
                .swap_904369_B_E(token1, false, -fusdc_out_0, U256::MAX)
                .unwrap();
            println!("amount_out_1: {amount_out_1}, fusdc_out_1: {fusdc_out_1}");
            assert_ne!(-fusdc_out_0, fusdc_out_1);
        },
    );
}
```

**Test result:**

```
     Running tests/lib.rs (target/debug/deps/lib-b27e97df8f1d4fcd)

running 1 test
amount_0_in: 367, fusdc_0_in: 58595
amount_1_in: 367, fusdc_1_in: 58595
amount_out_0: 833, fusdc_out_0: -58592
amount_out_1: -365, fusdc_out_1: 44866
test ethers_suite_orchestrated_uniswap_two_breakdown ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 16 filtered out; finished in 0.04s
```

As seen above, due to in the 2nd swap (`fusdc → token1`), the `token1` pool ran out of liquidity, only a portion of `fusdc_out_0` is used to perform the swap. `fusdc_out_0 ≠ fusdc_out_1` reverted the original `ethers_suite_uniswap_orchestrated_uniswap_two` test.

### Tools Used

VScode

### Recommended Mitigation Steps

Consider removing/relaxing the strict equality check.

**[af-afk (Superposition) confirmed](https://github.com/code-423n4/2024-08-superposition-findings/issues/31#event-14300539250)**

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/30#issuecomment-2369650553):**
 > The submission and its duplicates have correctly identified that a restriction imposed in `lib::swap_2_internal` will cause proper swaps to fail due to mandating strict equality for the funds consumed during a swap.
> 
> I believe a medium risk rating is appropriate given that it will cause a subset of transactions to fail with no harm beyond a Denial-of-Service.

***

## [[M-10] If liquidity is insufficient, users may need to pay more tokens in `swap2`](https://github.com/code-423n4/2024-08-superposition-findings/issues/12)
*Submitted by [shaflow2](https://github.com/code-423n4/2024-08-superposition-findings/issues/12), also found by [ZanyBonzy](https://github.com/code-423n4/2024-08-superposition-findings/issues/126), [OMEN](https://github.com/code-423n4/2024-08-superposition-findings/issues/51), [nnez](https://github.com/code-423n4/2024-08-superposition-findings/issues/43), and [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/17)*

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L210>

<https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L290>

### Impact

In the `swap_2_internal` function, if the first pool experiences a liquidity depletion, it could result in `amount_in` being less than `original_amount`. However, the contract might still require the user to transfer `original_amount` of tokens, causing the user to pay more tokens.

### Proof of Concept

When calling `swap2` to convert `token1` to `token2` through `fusdc`, if the `token1-fusdc` pool experiences a liquidity depletion, it will lead to the  issues that the calculated `amount_in` of `token1` will be less than the expected input `original_amount`.

```rust
    fn swap_2_internal(
        pools: &mut Pools,
        from: Address,
        to: Address,
        amount: U256,
        min_out: U256,
    ) -> Result<(U256, U256, U256, I256, i32, i32), Revert> {
        let original_amount = amount;

        let amount = I256::try_from(amount).map_err(|_| Error::SwapResultTooHigh)?;

        // swap in -> usdc
        let (amount_in, interim_usdc_out, final_tick_in) = pools.pools.setter(from).swap(
            true,
            amount,
            // swap with no price limit, since we use min_out instead
            tick_math::MIN_SQRT_RATIO + U256::one(),
        )?;
        ...
    }
```

After the `swap_2_internal` function completes, if the user is required to pay the protocol `original_amount` of `token1`, they end up paying `original_amount - amount_in` more tokens than they actually receive.

```rust
    pub fn swap_2_internal_erc20(
        pools: &mut Pools,
        from: Address,
        to: Address,
        amount: U256,
        min_out: U256,
        permit2: Option<Permit2Args>,
    ) -> Result<(U256, U256), Revert> {

        let (
            original_amount,
            amount_in,
            amount_out,
            _interim_usdc_out,
            _final_tick_in,
            _final_tick_out,
        ) = Self::swap_2_internal(pools, from, to, amount, min_out)?;

        // transfer tokens
        erc20::take(from, original_amount, permit2)?;
        erc20::transfer_to_sender(to, amount_out)?;

        Ok((amount_in, amount_out))
    }
}
```

### Recommended Mitigation Steps

Since compatibility with `Permit2` is required, it is recommended to refund the excess tokens back to the user.

```diff
    pub fn swap_2_internal_erc20(
        pools: &mut Pools,
        from: Address,
        to: Address,
        amount: U256,
        min_out: U256,
        permit2: Option<Permit2Args>,
    ) -> Result<(U256, U256), Revert> {

        let (
            original_amount,
            amount_in,
            amount_out,
            _interim_usdc_out,
            _final_tick_in,
            _final_tick_out,
        ) = Self::swap_2_internal(pools, from, to, amount, min_out)?;

        // transfer tokens
        erc20::take(from, original_amount, permit2)?;
        erc20::transfer_to_sender(to, amount_out)?;

+       if(original_amount > amount_in){
+           erc20::transfer_to_sender(to, original_amount - amount_in)?;
+       }

        Ok((amount_in, amount_out))
    }
}
```

**[af-afk (Superposition) confirmed and commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/12#issuecomment-2368007433):**
 > See [commit](https://github.com/fluidity-money/long.so/commit/e87f25180d0d0e65df4b2bc495652e9f50cc2cdd).

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/12#issuecomment-2369653730):**
 > The submission and its duplicates have correctly identified that a `swap_2_internal_erc20` operation will result in an overpayment of funds if the input amount is not consumed in full.
> 
> I believe a medium risk severity rating to be appropriate for this submission as it can lead to a minor fund loss under certain circumstances for the user.

***

## [[M-11] Volatile pools with higher fee structure cannot be created because of tick_spacing](https://github.com/code-423n4/2024-08-superposition-findings/issues/10)
*Submitted by [wasm\_it](https://github.com/code-423n4/2024-08-superposition-findings/issues/10)*

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L53> 

<https://github.com/code-423n4/2024-08-superposition/blob/main/pkg/seawater/src/pool.rs#L67>

### Impact

Provision of liquidity for pools with high volatility will not be possible as such pools cannot be initiated with a tick spacing basis point greater than 256 because of the `tick_spacing` datatype constrained to a u8.

### Proof of Concept

Less volatile pools usually have fee tiers in the range of 0.05% to 1%. But higher volatile pools go over 1% as a baseline and some pools can have a 3-5% fee tier depending on the volatility of the pool pairs. Since the protocol intends to be able to create pools for any tokens with sufficient liquidity, pools with exotic pairs in the fee range of `>` 1.3% cannot be instantiated.

```rs
pub fn init(
        &mut self,
        price: U256,
        fee: u32,
@>        tick_spacing: u8, // e.g 300 for a pool with 1.5% fee tier
        max_liquidity_per_tick: u128,
    ) -> Result<(), Revert> {
        assert_eq_or!(
            self.sqrt_price.get(),
            U256::ZERO,
            Error::PoolAlreadyInitialised
        );

        self.sqrt_price.set(price);
        self.cur_tick
            .set(I32::lib(&tick_math::get_tick_at_sqrt_ratio(price)?));

        self.fee.set(U32::lib(&fee));
@>        self.tick_spacing.set(U8::lib(&tick_spacing)); // @audit would revert at this point because the value exceeds the size of the datatype
        self.max_liquidity_per_tick
            .set(U128::lib(&max_liquidity_per_tick));

        Ok(())
    }
```

### Recommended Mitigation Steps

Uniswap uses a bigger datatype for this such as a 24-bit integer type. A bigger datatype would be sufficient for this such as u16.

### Assessed type

Context

**[af-afk (Superposition) confirmed and commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/10#issuecomment-2368401965):**
 > See [commit](https://github.com/fluidity-money/long.so/commit/d186c1ae6e65a375eca24f6864cf18a3e4940bc3).
> 
> We wound up enforcing a limit on the fee after some discussion that we don't intend to set fees that high.

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/10#issuecomment-2369655769):**
 > The submission has correctly identified that the data type used for the tick spacing of AMM pools is insufficient for volatile pools, causing them to become unusable due to their prices moving across ticks too swiftly.
> 
> I believe a medium-risk severity rating is appropriate given that the current AMM model is curated for volatile rather than stable pairs, rendering this scenario to have a non-negligible likelihood of manifesting in practice.

***

## [[M-12] No related function to set `fee_protocol`](https://github.com/code-423n4/2024-08-superposition-findings/issues/8)
*Submitted by [shaflow2](https://github.com/code-423n4/2024-08-superposition-findings/issues/8), also found by [prapandey031](https://github.com/code-423n4/2024-08-superposition-findings/issues/171), [zhaojohnson](https://github.com/code-423n4/2024-08-superposition-findings/issues/155), [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/144), [peanuts](https://github.com/code-423n4/2024-08-superposition-findings/issues/112), [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/24), and [wasm\_it](https://github.com/code-423n4/2024-08-superposition-findings/issues/14)*

There are no related functions to set `fee_protocol`, which prevents the protocol from accumulating protocol fees.

### Proof of Concept

The pool contract defines the protocol fee rate `fee_protocol`, but there is no function to set it.

```rust
#[solidity_storage]
pub struct StoragePool {
    ...
    fee_protocol: StorageU8,
    fee_growth_global_0: StorageU256,
    fee_growth_global_1: StorageU256,
    protocol_fee_0: StorageU128,
    protocol_fee_1: StorageU128,
    ...
}
```

The contract also defines the `collect_protocol` and `collect_protocol_7540_F_A_9_F` functions to collect fees. However, since the protocol fee rate cannot be set, the protocol will never accumulate any protocol fees.

[pkg/seawater/src/lib.rs](https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L1132)

```rust
    #[allow(non_snake_case)]
    pub fn collect_protocol_7540_F_A_9_F(
        &mut self,
        pool: Address,
        amount_0: u128,
        amount_1: u128,
        recipient: Address,
    ) -> Result<(u128, u128), Revert> {
        ...
    }
```

[pkg/seawater/src/pool.rs](https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/pool.rs#L538)

```rust
    pub fn collect_protocol(
        &mut self,
        amount_0: u128,
        amount_1: u128,
    ) -> Result<(u128, u128), Revert> {
        ...
    }
```

### Recommended Mitigation Steps

Add the relevant functions to enable protocol fees.

`pkg/seawater/src/pool.rs`:

```diff
+    pub fn set_fee_protocol(&mut self, new_fee_protocol: U256) {
+        self.fee_protocol.set(new_fee_protocol);
+    }
```

`pkg/seawater/src/lib.rs`:

```diff
+    #[allow(non_snake_case)]
+    pub fn set_fee_protocol(
+        &mut self,
+        pool: Address,
+        new_fee_protocol: U256,
+    ) -> Result<(), Revert> {
+        assert_eq_or!(
+            msg::sender(),
+            self.seawater_admin.get(),
+            Error::SeawaterAdminOnly
+        );
+
+        self.pools.setter(pool).set_fee_protocol(new_fee_protocol);
+
+        Ok(())
+    }
```

**[af-afk (Superposition) confirmed and commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/8#issuecomment-2368238751):**
 > See [commit](https://github.com/fluidity-money/long.so/commit/7706459ed85400117bcad1aa00425240699fd2b6).

**[0xsomeone (judge) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/8#issuecomment-2369656227):**
 > The submission and its duplicates have correctly identified that there is no mechanism to set the protocol fee in the system, causing fees to never accumulate in the current implementation.
> 
> I believe a severity of medium is appropriate given that its only harm is prospective earnings for the protocol itself.

***

# Low Risk and Non-Critical Issues

For this audit, 16 reports were submitted by wardens detailing low risk and non-critical issues. The [report highlighted below](https://github.com/code-423n4/2024-08-superposition-findings/issues/169) by **ZanyBonzy** received the top score from the judge.

*The following wardens also submitted reports: [oakcobalt](https://github.com/code-423n4/2024-08-superposition-findings/issues/36), [DadeKuma](https://github.com/code-423n4/2024-08-superposition-findings/issues/168), [prapandey031](https://github.com/code-423n4/2024-08-superposition-findings/issues/167), [SBSecurity](https://github.com/code-423n4/2024-08-superposition-findings/issues/166), [Tigerfrake](https://github.com/code-423n4/2024-08-superposition-findings/issues/164), [adeolu](https://github.com/code-423n4/2024-08-superposition-findings/issues/161), [ABAIKUNANBAEV](https://github.com/code-423n4/2024-08-superposition-findings/issues/129), [zhaojie](https://github.com/code-423n4/2024-08-superposition-findings/issues/98), [swapnaliss](https://github.com/code-423n4/2024-08-superposition-findings/issues/97), [devival](https://github.com/code-423n4/2024-08-superposition-findings/issues/82), [zhaojohnson](https://github.com/code-423n4/2024-08-superposition-findings/issues/63), [Testerbot](https://github.com/code-423n4/2024-08-superposition-findings/issues/52), [Nikki](https://github.com/code-423n4/2024-08-superposition-findings/issues/49), [shaflow2](https://github.com/code-423n4/2024-08-superposition-findings/issues/41), and [Silvermist](https://github.com/code-423n4/2024-08-superposition-findings/issues/39).*

## [L-01] OwnershipNFTs.sol doesn't fully match EIP-721's implementation

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L182

### Impact

`tokenURI` doesn't enforce that the token being checked is a valid token, which can lead to malicious users impersonating bogus NFTs as the ownership NFT. Unsuspecting users would attempt to query the token uri and would be returned with a valid uri, since the function doesn't ensure that the tokenId is a valid NFT.

Also, according to EIP-721 metadata standard, the function should revert if `_tokenId` is not a valid NFT.

> /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
>    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC

```solidity
    function tokenURI(uint256 /* _tokenId */) external view returns (string memory) {
        return TOKEN_URI;
    }
```

### Recommended Mitigation Steps

Add the check for NFT existence in the function by checking that the owner is not `address(0)`.

## [L-02] Existing backdoor for owner/operator in the `approve` function

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L160-L163

### Impact

The approve function allows operator and owner to approve themselves to spend the token. This can be used to give themselves a backdoor to the token. If for example the operator's status is to be revoked, he can always call the `approve` function on the token, to approve himself to spend the token. So even if his operator status is revoked, he still has access to the tokens.

```solidity
    function approve(address _approved, uint256 _tokenId) external payable {
        _requireAuthorised(msg.sender, _tokenId);
        getApproved[_tokenId] = _approved;
    }
```

### Recommended Mitigation Steps

Ensure that the owner/operator cannot approve themselves to spend a token.

## [L-03] Consider automatically collecting fees before transferring positions

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L554-L569

### Impact

`transfer_position_E_E_C7_A3_C_D` directly removes the positions from the sender and adds it to the receiver without making considerations for potential fees that the position has accrued. 

```rust
    pub fn transfer_position_E_E_C7_A3_C_D(
        &mut self,
        id: U256,
        from: Address,
        to: Address,
    ) -> Result<(), Revert> {
        assert_eq_or!(msg::sender(), self.nft_manager.get(), Error::NftManagerOnly);

        self.remove_position(from, id);
        self.grant_position(to, id);

        #[cfg(feature = "log-events")]
        evm::log(events::TransferPosition { from, to, id });

        Ok(())
    }
```

### Recommended Mitigation Steps

Recommend introducing `collect_single_to_6_D_76575_F` into the `transfer_position_E_E_C7_A3_C_D` function to help users directly claim fees before transferring their positions.

## [L-04] Functions to claim fees should be accessible even when pool is disabled

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/pool.rs#L562-L565

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/pool.rs#L538-L559

### Impact

The `collect` and `collect_protocol` functions allow users and protocol admins to claim their fees. These functions are, however, not accessible when the pool is disabled. As a rule of thumb, functions to remove rewards or withdraw tokens from a protocol should always be accessible to help users claim resuce their tokens. Also a malicious admin can disable the pool and renounce his ownership, permanently locking the tokens in the protocol.

```rust
    pub fn collect(&mut self, id: U256) -> Result<(u128, u128), Revert> {
>>      assert_or!(self.enabled.get(), Error::PoolDisabled);
        Ok(self.positions.collect_fees(id))
    }
```

```rust
    pub fn collect_protocol(
        &mut self,
        amount_0: u128,
        amount_1: u128,
    ) -> Result<(u128, u128), Revert> {
>>      assert_or!(self.enabled.get(), Error::PoolDisabled);

        let owed_0 = self.protocol_fee_0.get().sys();
        let owed_1 = self.protocol_fee_1.get().sys();

        let amount_0 = u128::min(amount_0, owed_0);
        let amount_1 = u128::min(amount_1, owed_1);

        if amount_0 > 0 {
            self.protocol_fee_0.set(U128::lib(&(owed_0 - amount_0)));
        }
        if amount_1 > 0 {
            self.protocol_fee_1.set(U128::lib(&(owed_1 - amount_1)));
        }

        Ok((amount_0, amount_1))
    }
```

### Recommended Mitigation Steps

Recommend removing the check for pool activity in the functions.

## [L-05] Non-existent function in referenced on SeawaterAMM.sol

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L487-L502

### Impact

The `incrPositionPermit25468326E` function is implemented in SeawaterAMM.sol, but isn't implemented in any of the pool's backend library. As a result any calls to the function will always fail.

```solidity
    function incrPositionPermit25468326E(
        address /* token */,
        uint256 /* id */,
        uint256 /* amount0Min */,
        uint256 /* amount1Min */,
        uint256 /* nonce0 */,
        uint256 /* deadline0 */,
        uint256 /* amount0Max */,
        bytes memory /* sig0 */,
        uint256 /* nonce1 */,
        uint256 /* deadline1 */,
        uint256 /* amount1Max */,
        bytes memory /* sig1 */
    ) external returns (uint256, uint256) {
        directDelegate(_getExecutorUpdatePosition());
    }
```

### Recommended Mitigation Steps

Recommend removing the unimplemented function.

## [L-06] OwnershipNFTs.sol holds payable functions but have no way to rescue 

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L118-L162

### Impact

A number of functions in OwnershipNFTs.sol are marked as payable, meaning they can receive ETH. But the contract implementation doesn't make use of ETH, nor is there any function to recover any ETH sent. As a result the tokens will be lost forever.

```solidity
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata /* _data */
    ) external payable {
        // checks that the user is authorised
        _transfer(_from, _to, _tokenId);
    }

    /// @inheritdoc IERC721Metadata
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        // checks that the user is authorised
        _transfer(_from, _to, _tokenId);
    }

    /// @inheritdoc IERC721Metadata
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        _transfer(_from, _to, _tokenId);
        _onTransferReceived(msg.sender, _from, _to, _tokenId);
    }

    /// @inheritdoc IERC721Metadata
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata /* _data */
    ) external payable {
        _transfer(_from, _to, _tokenId);
        _onTransferReceived(msg.sender, _from, _to, _tokenId);
    }

    /// @inheritdoc IERC721Metadata
    function approve(address _approved, uint256 _tokenId) external payable {
        _requireAuthorised(msg.sender, _tokenId);
        getApproved[_tokenId] = _approved;
    }
```

### Recommended Mitigation Steps

Recommend removing the payable modifier from the listed functions, or introducing a function to recover any excess tokens in the contract.

## [L-07] Function to directly adjust position is not exposed in SeawaterAMM.sol

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L730

### Impact

lib.rs holds the `adjust_position_internal` which allows users to change their position details according to specified giving bool. However, this function is not exposed in SeawaterAMM.sol, so as such cannot be directly queried. Also, since there's an issue with the `decrPosition09293696` function (an incorrect function definition), there's no way to for users to reduce their positions.

### Recommended Mitigation Steps

Recommend exposing the function.

## [L-08] Functions involving permit can easily be dossed

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L322

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L281

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L249

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L230

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L487

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L408

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L439

### Impact

The `swap_permit_2_E_E84_A_D91`, `swap_2_exact_in_permit_2_36_B2_F_D_D8`, `incrPositionPermit25468326E`, `swapOutPermit23273373B`, `swapOut5E08A399`, `swapInPermit2CEAAB576`, `swap2ExactInPermit236B2FDD8` etc., functions allow off-chain signed approvals to be used on-chain, saving gas and improving user experience. However, including these functions will make the transaction susceptible to DOS via frontrunning. An attacker can observe the transaction in the mempool, extract the permit signature and values from the calldata and execute the permit before the original transaction is processed. This would consume the nonce associated with the user's permit and cause the original transaction to fail due to the now-invalid nonce.

This attack vector has been previously described in Permission Denied - [The Story of an EIP that Sinned](https://www.trust-security.xyz/post/permission-denied).

### Recommended Mitigation Steps

Recommend wrapping the permit functionalities in a try catch block or its rust equivalent. Something like this may work.

```solidity
try IERC20Permit(token).permit(msgSender, address(this), value, deadline, v, r, s) {
    // Permit executed successfully, proceed
} catch {
    // Check allowance to see if permit was already executed
    uint256 currentAllowance = IERC20(token).allowance(msgSender, address(this));
    if(currentAllowance < value) {
        revert("Permit failed and allowance insufficient");
    }
    // Otherwise, proceed as if permit was successful
}
```

## [L-09] Lack of a deadline parameter during interactions with pools

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L315

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L327

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L408

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L439

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L230

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L249

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L262

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L281

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L304

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/SeawaterAMM.sol#L322

### Impact

Functions `swap_904369_B_E`, `swap_2_exact_in_41203_F1_D`, `swap_permit_2_E_E84_A_D91`, `swap_2_exact_in_permit_2_36_B2_F_D_D8`, `swapOutPermit23273373B`, `swapOut5E08A399`, `swapIn32502CA71`, `swapInPermit2CEAAB576` etc., are missing deadline checks.

As front-running is a key aspect of AMM design, the deadline is a useful tool to ensure that user transactions cannot be "saved for later" by miners or stay longer than needed in the mempool. The longer transactions stay in the mempool, the more likely it is that MEV bots can steal positive slippage from the transaction.

### Recommended Mitigation Steps

Consider introducing a deadline parameter in all the pointed-out functions.

## [L-10] Ownership NFts lack the mint and burn functionalities

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L13

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L495-L544

### Impact

Not sure the best severity for this, as the contract is described as an interface for tracking ownership positions. Yet at the same time, it holds functionalities that are pertinent to real NFTs, it can be approved and transfered. In any case, the contract lacks any functionality to mint and burn the tokens. As such, these tokens can't really be minted or burnt from users. 

Also, when positions are minted/burned from the pool, no function is called to mint/burn NFTs from the caller.

```rs
    pub fn mint_position_B_C5_B086_D(
        &mut self,
        pool: Address,
        lower: i32,
        upper: i32,
    ) -> Result<U256, Revert> {
        let id = self.next_position_id.get();
        self.pools.setter(pool).create_position(id, lower, upper)?;

        self.next_position_id.set(id + U256::one());

        let owner = msg::sender();

        self.grant_position(owner, id);

        #[cfg(feature = "log-events")]
        evm::log(events::MintPosition {
            id,
            owner,
            pool,
            lower,
            upper,
        });

        Ok(id)
    }
```

```rs
    #[allow(non_snake_case)]
    pub fn burn_position_AE401070(&mut self, id: U256) -> Result<(), Revert> {
        let owner = msg::sender();
        assert_eq_or!(
            self.position_owners.get(id),
            owner,
            Error::PositionOwnerOnly
        );

        self.remove_position(owner, id);

        #[cfg(feature = "log-events")]
        evm::log(events::BurnPosition { owner, id });

        Ok(())
    }
```

## [L-11] Remove debugging code from production and refurbish test suite

https://github.com/search?q=repo%3Acode-423n4%2F2024-08-superposition%20%23%5Bcfg(feature%20%3D%20%22testing-dbg%22)%5D&type=code

### Impact

Lots of the contracts in scope still hold the debugging code. As a result, the codebase looked a bit cluttered. Also, the test suite and its configuration was very difficult to get under control. Lots of weird errors and failures.

```rs
#[cfg(feature = "testing-dbg")]
```

## [L-12] `calldata` is not used during NFT transfers

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L148-L157

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/sol/OwnershipNFTs.sol#L118-L126

### Impact

`transferFrom` and `safeTransferFrom` take the `calldata` parameter but its not in used, especially in the `_onTransferReceived` hook. External integrations depending on the calldata will have issues due to the parameter not being used.

```solidity
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata /* _data */
    ) external payable {
        // checks that the user is authorised
        _transfer(_from, _to, _tokenId);
    }
```

```solidity
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata /* _data */
    ) external payable {
        _transfer(_from, _to, _tokenId);
        _onTransferReceived(msg.sender, _from, _to, _tokenId);
    }
```

### Recommended Mitigation Steps

Recommend implementing the use of this parameter, or removing the functions since it's redundant.

## [L-13] Prevent transfer to self when transferring positions

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L553-L569

### Impact

`transfer_position_E_E_C7_A3_C_D` allows users to transfer tokens to themselves. It should return if from `==` to.

```rust
    pub fn transfer_position_E_E_C7_A3_C_D(
        &mut self,
        id: U256,
        from: Address,
        to: Address,
    ) -> Result<(), Revert> {
        assert_eq_or!(msg::sender(), self.nft_manager.get(), Error::NftManagerOnly);

        self.remove_position(from, id);
        self.grant_position(to, id);

        #[cfg(feature = "log-events")]
        evm::log(events::TransferPosition { from, to, id });

        Ok(())
    }
```

## [L-14] `swap_2_exact_in_41203_F1_D` shouldn't allow swapping between same pools

https://github.com/code-423n4/2024-08-superposition/blob/4528c9d2dbe1550d2660dac903a8246076044905/pkg/seawater/src/lib.rs#L327-L336

### Impact

`swap_2_exact_in_41203_F1_D` allows swapping between the same pools which malicious users can attempt to leverage, trying to drain pool liqudity. Recommend reverting or returning if from `==` to.

```rs
    pub fn swap_2_exact_in_41203_F1_D(
        &mut self,
        from: Address,
        to: Address,
        amount: U256,
        min_out: U256,
    ) -> Result<(U256, U256), Revert> {
        Pools::swap_2_internal_erc20(self, from, to, amount, min_out, None)
    }
}
```

**[af-afk (Superposition) commented](https://github.com/code-423n4/2024-08-superposition-findings/issues/169#issuecomment-2357409776):**
 > [L-01] - This wasn't a goal, but we'll do fix it anyway.<br>
> [L-02] - We'll allow this, in some circumstances (hack of a third party), we want to have the power to do this. We'll delegate the power to a DAO.<br>
> [L-03] - We won't implement this. It should be the responsibility of the caller to know when to collect accrued fees.<br>
> [L-04] - We won't fix this, the single contract environment increases the risk profile of the math going wrong, so we don't want to support users collecting fees in an emergency context. Also, the admin being malicious is not a part of the threat model.<br>
> [L-05] - We'll remove this.<br>
> [L-06] - We'll remove the payable functions.<br>
> [L-07] - This will be fixed with correct `decrPosition` code. We won't make the recommendations in this submission.<br>
> [L-08] - That's very interesting! We won't however fix it, we don't believe that in practice this is likely to take place.<br>
> [L-09] - We have a centralised sequencer, the AMM is deployed on our chain. For this reason, we don't check for the deadline. So we won't implement a change for this. Also, the end user is ultimately going to be taking advantage of `permit2`, which includes a deadline anyway.<br>
> [L-10] - We won't make these suggestions! It should mirror the main contract and we won't include the NFT manager in the UX flow for positions.<br>
> [L-11] - We acknowledge it's cluttered in its current state, and we'll make an adjustment in the future to improve the error reporting for debugging. But we won't immediately make these fixes.<br>
> [L-12] - We won't make this change.<br>
> [L-13] - We won't make this change, if the user wants to waste their time without any harmful side effects with something like this, they're welcome to.<br>
> [L-14] - We'll make this change.

***

# Disclosures

C4 is an open organization governed by participants in the community.

C4 audits incentivize the discovery of exploits, vulnerabilities, and bugs in smart contracts. Security researchers are rewarded at an increasing rate for finding higher-risk issues. Audit submissions are judged by a knowledgeable security researcher and solidity and rust developer and disclosed to sponsoring developers. C4 does not conduct formal verification regarding the provided code but instead provides final verification.

C4 does not provide any guarantee or warranty regarding the security of this project. All smart contract software should be used at the sole risk and responsibility of users.
