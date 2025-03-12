// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {IMinter} from './IMinter.sol';
import {IARTH} from '../Arth/IARTH.sol';
import {IERC20} from '../ERC20/IERC20.sol';
import {IARTHX} from '../ARTHX/IARTHX.sol';
import {SafeMath} from '../Math/SafeMath.sol';
import {IARTHPool} from '../Arth/Pools/IARTHPool.sol';
import {ILiquidityGauge} from './ILiquidityGauge.sol';
import {IStableSwap3Pool} from './IStableSwap3Pool.sol';
import {IARTHController} from '../Arth/IARTHController.sol';
import {AccessControl} from '../Governance/AccessControl.sol';
import {IMetaImplementationUSD} from './IMetaImplementationUSD.sol';

/**
 * @title CurveAMO.
 * @author MahaDAO.
 *
 * Original code written by:
 * - Travis Moore, Jason Huan, Same Kazemian, Sam Sun.
 */
contract CurveAMO is AccessControl {
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    IMetaImplementationUSD private arth3crv_metapool;
    IStableSwap3Pool private three_pool;
    ILiquidityGauge private gauge_arth3crv;
    IMinter private crv_minter;
    IERC20 private three_pool_erc20;
    IARTH private ARTH;
    IARTHPool private pool;
    IARTHX private ARTHX;
    IERC20 private collateralToken;
    IERC20 private CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IARTHController private controller;

    address public arth3crv_metapool_address;
    address public three_pool_address;
    address public three_pool_token_address;
    address public gauge_3crv_address;
    address public crv_minter_address;
    address public arth_contract_address;
    address public arthx_contract_address;
    address public collateralToken_address;
    address public timelock_address;
    address public ownerAddress;
    address public custodian_address;
    address public pool_address;

    // Tracks ARTH
    uint256 public minted_arth_historical = 0;
    uint256 public burned_arth_historical = 0;

    // Max amount of ARTH outstanding the contract can mint from the ArthPool
    uint256 public max_arth_outstanding = uint256(2000000e18);

    // Tracks collateral
    uint256 public borrowed_collat_historical = 0;
    uint256 public returned_collat_historical = 0;

    // Max amount of collateral the contract can borrow from the ArthPool
    uint256 public collat_borrow_cap = uint256(20000e6);

    // Minimum collateral ratio needed for new ARTH minting
    uint256 public min_cr = 850000;

    // Number of decimals under 18, for collateral token
    uint256 private missing_decimals;

    // Precision related
    uint256 private constant PRICE_PRECISION = 1e6;

    // Minimum acceptable ratio in terms of collateral deposited to LP tokens received for 3CRV add_liquidity; 1e6
    uint256 public add_liq_slippage_3crv = 900000;

    // Minimum acceptable ratio in terms of ARTH + 3CRV deposited to LP tokens received for ARTH3CRV-f metapool add_liquidity; 1e6
    uint256 public add_liq_slippage_metapool = 900000;

    // 3pool collateral index
    int128 public THREE_POOL_COIN_INDEX = 1;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _arth_contract_address,
        address _arthx_contract_address,
        address _collateralAddress,
        address _creator_address,
        address _custodian_address,
        address _timelock_address
    ) {
        ARTH = IARTH(_arth_contract_address);
        ARTHX = IARTHX(_arthx_contract_address);
        arth_contract_address = _arth_contract_address;
        arthx_contract_address = _arthx_contract_address;
        collateralToken = IERC20(_collateralAddress);
        missing_decimals = uint256(18).sub(collateralToken.decimals());
        timelock_address = _timelock_address;
        ownerAddress = _creator_address;
        custodian_address = _custodian_address;

        missing_decimals = uint256(18).sub(collateralToken.decimals());
    }

    /* ========== MODIFIERS ========== */

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == timelock_address || msg.sender == ownerAddress,
            'You are not the owner or the governance timelock'
        );
        _;
    }

    modifier onlyCustodian() {
        require(
            msg.sender == custodian_address,
            'You are not the rewards custodian'
        );
        _;
    }

    /* ========== VIEWS ========== */

    function showAllocations()
        external
        view
        returns (uint256[9] memory allocations)
    {
        // IMPORTANT
        // Should ONLY be used externally, because it may fail if any one of the functions below fail

        // Get collateral info
        uint256[4] memory collat_info = getCollateralGMUBalanceExtended();

        uint256 arth_withdrawable =
            (collat_info[0])
                .mul(controller.getGlobalCollateralRatio())
                .mul(ARTH.balanceOf(arth3crv_metapool_address))
                .div(collat_info[1])
                .div(uint256(1e6));

        allocations[0] = ARTH.balanceOf(address(this)); // Unallocated ARTH
        allocations[1] = arth_withdrawable; // ARTH withdrawable from the metapool LP
        allocations[2] = collateralToken.balanceOf(address(this)); // Free collateral
        allocations[3] = collat_info[3]; // Collateral withdrawable from the metapool LP
        allocations[4] = freeCRV(); // Free CRV
        allocations[5] = 0; // TODO: Staked CRV

        uint256 sum_arth = allocations[0];
        sum_arth = sum_arth.add(allocations[1]);
        allocations[6] = sum_arth; // Total ARTH possessed in various forms

        uint256 sum_collat = allocations[2];
        sum_collat = sum_collat.add(allocations[3]);
        allocations[7] = sum_collat; // Total Collateral possessed in various forms

        uint256 sum_crv = allocations[4];
        sum_crv = sum_crv.add(allocations[5]);
        allocations[8] = sum_crv; // Total CRV possessed in various forms
    }

    function getCollateralGMUBalanceExtended()
        public
        view
        returns (uint256[4] memory return_arr)
    {
        // ------------LP Balance------------
        // Free LP
        uint256 lp_owned = arth3crv_metapool.balanceOf(address(this));

        // Staked in the gauge
        // TODO
        lp_owned = lp_owned.add(gauge_arth3crv.balanceOf(address(this)));

        // ------------3pool Withdrawable------------
        // Linear approximation of metapool withdrawable amounts at floor price (globalCollateralRatio)
        // TODO: Need to recreate metapool get_D() logic to simulate what would happen if ARTH price went to CR
        // threeCRV_withdrawable
        uint256 arth3crv_supply = arth3crv_metapool.totalSupply();

        uint256 _3pool_withdrawable;
        if (arth3crv_supply > 0) {
            _3pool_withdrawable = lp_owned
                .mul(controller.getGlobalCollateralRatio())
                .mul(three_pool_erc20.balanceOf(arth3crv_metapool_address))
                .div(arth3crv_supply)
                .div(uint256(1e6));
        } else _3pool_withdrawable = 0;

        // ------------Collateral Balance------------
        // Free Collateral
        uint256 usdc_owned = collateralToken.balanceOf(address(this));

        // Returns amount of USDC withdrawable if the contract redeemed all of its 3pool tokens from the base 3pool for USDC,
        // with the 3pool coming from ARTH3CRV-f-2 remove_liquidity()
        usdc_owned = usdc_owned.add(
            three_pool.calc_withdraw_one_coin(_3pool_withdrawable, 1)
        );

        // // Placeholder; can be used for CR calculations - up to the AMO design
        // // arth_withdrawable
        // return_arr[2] = return_arr[0].mul(uint(1e6)).mul(ARTH.balanceOf(arth3crv_metapool_address)).div(arth3crv_metapool.totalSupply()).div(ARTH.globalCollateralRatio());

        return [lp_owned, arth3crv_supply, _3pool_withdrawable, usdc_owned];
    }

    function getCollateralGMUBalance() public view returns (uint256) {
        uint256[4] memory collat_info = getCollateralGMUBalanceExtended();
        return (collat_info[3] * (10**missing_decimals));
    }

    function get_D() public view returns (uint256) {
        // Setting up constants
        uint256 _A = arth3crv_metapool.A_precise();
        uint256 A_PRECISION = 100;
        uint256[2] memory _xp =
            [
                three_pool_erc20.balanceOf(arth3crv_metapool_address),
                ARTH.balanceOf(arth3crv_metapool_address)
            ];

        uint256 N_COINS = 2;
        uint256 S;
        for (uint256 i = 0; i < N_COINS; i++) {
            S += _xp[i];
        }
        if (S == 0) {
            return 0;
        }
        uint256 D = S;
        uint256 Ann = N_COINS * _A;

        uint256 Dprev = 0;
        uint256 D_P;
        // Iteratively converge upon D
        for (uint256 i = 0; i < 256; i++) {
            D_P = D;
            for (uint256 j = 0; j < N_COINS; j++) {
                D_P = (D * D) / (_xp[j] * N_COINS);
            }
            Dprev = D;
            D =
                (((Ann * S) / A_PRECISION + D_P * N_COINS) * D) /
                (((Ann - A_PRECISION) * D) / A_PRECISION + (N_COINS + 1) * D_P);

            // Check if iteration has converged
            if (D > Dprev) {
                if (D - Dprev <= 1) {
                    return D;
                }
            } else {
                if (Dprev - D <= 1) {
                    return D;
                }
            }
        }

        // Placeholder, in case it does not converge (should do so within <= 4 rounds)
        // TODO: consider changing this to return a safe value that won't brick everything if it is reached
        revert('Convergence not reached');
    }

    // TESTING PURPOSES ONLY – WILL BE REMOVED
    function get_D_and_iterations() public view returns (uint256, uint256) {
        // Setting up constants
        uint256 _A = arth3crv_metapool.A_precise();
        uint256 A_PRECISION = 100;
        uint256[2] memory _xp =
            [
                three_pool_erc20.balanceOf(arth3crv_metapool_address),
                ARTH.balanceOf(arth3crv_metapool_address)
            ];

        uint256 N_COINS = 2;
        uint256 S;
        for (uint256 i = 0; i < N_COINS; i++) {
            S += _xp[i];
        }
        if (S == 0) {
            return (0, 0);
        }
        uint256 D = S;
        uint256 Ann = N_COINS * _A;

        uint256 Dprev = 0;
        uint256 D_P;
        // Iteratively converge upon D
        for (uint256 i = 0; i < 256; i++) {
            D_P = D;
            for (uint256 j = 0; j < N_COINS; j++) {
                D_P = (D * D) / (_xp[j] * N_COINS);
            }
            Dprev = D;
            D =
                (((Ann * S) / A_PRECISION + D_P * N_COINS) * D) /
                (((Ann - A_PRECISION) * D) / A_PRECISION + (N_COINS + 1) * D_P);

            // Check if iteration has converged
            if (D > Dprev) {
                if (D - Dprev <= 1) {
                    return (D, i);
                }
            } else {
                if (Dprev - D <= 1) {
                    return (D, i);
                }
            }
        }

        revert('Convergence not reached');
    }

    // returns hypothetical reserves of metapool if the ARTH price went to the CR,
    // assuming no removal of liquidity from the metapool.

    // I will add safemath later, currently still need ease of reading regular operations
    uint256 public convergence_window = 1e15; // 1/10th of a cent, TODO: add a setter

    function iterate()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 arth_balance = ARTH.balanceOf(arth3crv_metapool_address);
        uint256 crv3_balance =
            three_pool_erc20.balanceOf(arth3crv_metapool_address);

        // 3crv is usually slightly above $1 due to collecting 3pool swap fees
        uint256 one_dollar_3crv =
            uint256(1e18).div(three_pool.get_virtual_price());

        uint256 floor_price_arth =
            uint256(1e18).mul(controller.getGlobalCollateralRatio()).div(1e6);

        uint256 arth_received;
        for (uint256 i = 0; i < 256; i++) {
            // how much ARTH received for $1 worth of 3CRV
            arth_received = arth3crv_metapool.get_dy(
                1,
                0,
                one_dollar_3crv,
                [arth_balance, crv3_balance]
            );
            if (arth_received <= floor_price_arth + convergence_window) {
                return (arth_balance, crv3_balance, i);
            } else if (arth_received + convergence_window <= floor_price_arth) {
                // if overshot
                return (arth_balance, crv3_balance, i);
            }
            uint256 arth_to_swap = arth_balance / 10;
            crv3_balance =
                crv3_balance -
                arth3crv_metapool.get_dy(
                    0,
                    1,
                    arth_to_swap,
                    [arth_balance, crv3_balance]
                );
            arth_balance = arth_balance + arth_to_swap;
        }
        revert("Didn't find hypothetical point on curve within 256 rounds");
    }

    // In ARTH
    function arthBalance() public view returns (uint256) {
        if (minted_arth_historical >= burned_arth_historical)
            return minted_arth_historical.sub(burned_arth_historical);
        else return 0;
    }

    // In collateral
    function collateralBalance() public view returns (uint256) {
        if (borrowed_collat_historical >= returned_collat_historical)
            return borrowed_collat_historical.sub(returned_collat_historical);
        else return 0;
    }

    // Amount of ARTH3CRV deposited in the gauge contract
    function metapoolLPInGauge() public view returns (uint256) {
        return gauge_arth3crv.balanceOf(address(this));
    }

    // This function is problematic because it can be either a view or non-view
    // // Amount of CRV rewards mintable / claimable
    // function claimableCRV() public view returns (uint256){
    //     return gauge_arth3crv.claimable_tokens(address(this));
    //     // return 0;
    // }

    // Amount of CRV in the contract
    function freeCRV() public view returns (uint256) {
        return CRV.balanceOf(address(this));
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // This is basically a workaround to transfer USDC from the ArthPool to this investor contract
    // This contract is essentially marked as a 'pool' so it can call OnlyPools functions like poolMint and poolBurnFrom
    // on the main ARTH contract
    // It mints ARTH from nothing, and redeems it on the target pool for collateral and ARTHX
    // The burn can be called separately later on
    function mintRedeemPart1(uint256 arth_amount)
        public
        onlyByOwnerOrGovernance
    {
        //require(allow_yearn || allow_aave || allow_compound, 'All strategies are currently off');
        uint256 redemptionFee = pool.redemptionFee();
        uint256 col_price_usd = pool.getCollateralPrice();
        uint256 globalCollateralRatio = controller.getGlobalCollateralRatio();
        uint256 redeem_amount_E6 =
            (arth_amount.mul(uint256(1e6).sub(redemptionFee))).div(1e6).div(
                10**missing_decimals
            );
        uint256 expected_collat_amount =
            redeem_amount_E6.mul(globalCollateralRatio).div(1e6);
        expected_collat_amount = expected_collat_amount.mul(1e6).div(
            col_price_usd
        );

        require(
            collateralBalance().add(expected_collat_amount) <=
                collat_borrow_cap,
            'Borrow cap reached'
        );
        borrowed_collat_historical = borrowed_collat_historical.add(
            expected_collat_amount
        );

        // Mint the arth
        ARTH.poolMint(address(this), arth_amount);

        // Redeem the arth
        ARTH.approve(address(pool), arth_amount);
        pool.redeemFractionalARTH(arth_amount, 0, 0);
    }

    function mintRedeemPart2() public onlyByOwnerOrGovernance {
        pool.collectRedemption();
    }

    // Give USDC profits back
    function giveCollatBack(uint256 amount) public onlyByOwnerOrGovernance {
        collateralToken.transfer(address(pool), amount);
        returned_collat_historical = returned_collat_historical.add(amount);
    }

    // Burn unneeded or excess ARTH
    function burnARTH(uint256 arth_amount) public onlyByOwnerOrGovernance {
        // ARTH.burn(arth_amount);
        burned_arth_historical = burned_arth_historical.add(arth_amount);
    }

    function burnARTHX(uint256 amount) public onlyByOwnerOrGovernance {
        ARTHX.approve(address(this), amount);
        ARTHX.poolBurnFrom(address(this), amount);
    }

    function metapoolDeposit(uint256 _arth_amount, uint256 _collateralAmount)
        public
        onlyByOwnerOrGovernance
        returns (uint256 metapool_LP_received)
    {
        // Mint the ARTH component
        ARTH.poolMint(address(this), _arth_amount);
        minted_arth_historical = minted_arth_historical.add(_arth_amount);
        require(
            arthBalance() <= max_arth_outstanding,
            'Too much ARTH would be minted [max_arth_outstanding reached]'
        );

        // Approve the collateral to be added to 3pool
        collateralToken.approve(address(three_pool), _collateralAmount);

        // Convert collateral into 3pool
        uint256[3] memory three_pool_collaterals;
        three_pool_collaterals[
            uint256(uint128(THREE_POOL_COIN_INDEX))
        ] = _collateralAmount;
        three_pool.add_liquidity(three_pool_collaterals, 0);

        // Approve the 3pool for the metapool
        uint256 threeCRV_received = three_pool_erc20.balanceOf(address(this));
        three_pool_erc20.approve(arth3crv_metapool_address, threeCRV_received);

        // Approve the ARTH for the metapool
        ARTH.approve(arth3crv_metapool_address, _arth_amount);

        // Add the ARTH and the collateral to the metapool
        metapool_LP_received = arth3crv_metapool.add_liquidity(
            [_arth_amount, threeCRV_received],
            0
        );

        // Make sure the collateral ratio did not fall too much
        uint256 current_collateral_E18 =
            (controller.getGlobalCollateralRatio()).mul(10**missing_decimals);
        uint256 cur_arth_supply = ARTH.totalSupply();
        uint256 new_cr =
            (current_collateral_E18.mul(PRICE_PRECISION)).div(cur_arth_supply);
        require(
            new_cr >= min_cr,
            'Minting caused the collateral ratio to be too low'
        );

        return metapool_LP_received;
    }

    function metapoolWithdraw(uint256 _metapool_lp_in, bool burn_the_arth)
        public
        onlyByOwnerOrGovernance
        returns (uint256 arth_received)
    {
        // // Approve the metapool LP tokens for the metapool contract
        // arth3crv_metapool.approve(address(this), _metapool_lp_in);

        // Withdraw ARTH and 3pool from the metapool
        uint256[2] memory min_amounts;
        uint256[2] memory result_arr =
            arth3crv_metapool.remove_liquidity(_metapool_lp_in, min_amounts);
        arth_received = result_arr[0];
        uint256 three_pool_received = result_arr[1];

        // Convert the 3pool into the collateral
        three_pool_erc20.approve(address(three_pool), three_pool_received);
        three_pool.remove_liquidity_one_coin(
            three_pool_received,
            THREE_POOL_COIN_INDEX,
            0
        );

        // Optionally burn the ARTH
        if (burn_the_arth) {
            burnARTH(arth_received);
        }
    }

    // Deposit Metapool LP tokens into the Curve DAO for gauge rewards, if any
    function depositToGauge(uint256 _metapool_lp_in)
        public
        onlyByOwnerOrGovernance
    {
        // Approve the metapool LP tokens for the gauge contract
        arth3crv_metapool.approve(address(gauge_arth3crv), _metapool_lp_in);

        // Deposit the metapool LP into the gauge contract
        gauge_arth3crv.deposit(_metapool_lp_in);
    }

    // Withdraw Metapool LP from Curve DAO back to this contract
    function withdrawFromGauge(uint256 _metapool_lp_out)
        public
        onlyByOwnerOrGovernance
    {
        gauge_arth3crv.withdraw(_metapool_lp_out);
    }

    // Retrieve CRV gauge rewards, if any
    function collectCRVFromGauge() public onlyByOwnerOrGovernance {
        crv_minter.mint(address(this));
    }

    /* ========== Custodian ========== */

    // NOTE: The custodian_address can be set to the governance contract to be used as
    // a mega-voter or sorts. The CRV here can be converted to veCRV and then used to vote
    function withdrawCRVRewards() public onlyCustodian {
        CRV.transfer(custodian_address, CRV.balanceOf(address(this)));
    }

    /* ========== RESTRICTED GOVERNANCE FUNCTIONS ========== */

    function setTimelock(address new_timelock)
        external
        onlyByOwnerOrGovernance
    {
        timelock_address = new_timelock;
    }

    function setOwner(address _ownerAddress) external onlyByOwnerOrGovernance {
        ownerAddress = _ownerAddress;
    }

    function setMiscRewardsCustodian(address _custodian_address)
        external
        onlyByOwnerOrGovernance
    {
        custodian_address = _custodian_address;
    }

    function setPool(address _pool_address) external onlyByOwnerOrGovernance {
        pool_address = _pool_address;
        pool = IARTHPool(_pool_address);
    }

    function setThreePool(
        address _three_pool_address,
        address _three_pool_token_address
    ) external onlyByOwnerOrGovernance {
        three_pool_address = _three_pool_address;
        three_pool = IStableSwap3Pool(_three_pool_address);
        three_pool_token_address = _three_pool_token_address;
        three_pool_erc20 = IERC20(_three_pool_token_address);
    }

    function setMetapool(address _metapool_address)
        public
        onlyByOwnerOrGovernance
    {
        arth3crv_metapool_address = _metapool_address;
        arth3crv_metapool = IMetaImplementationUSD(_metapool_address);
    }

    function setGauge(address _gauge_3crv_address)
        public
        onlyByOwnerOrGovernance
    {
        gauge_3crv_address = _gauge_3crv_address;
        gauge_arth3crv = ILiquidityGauge(_gauge_3crv_address);

        // Set the minter too
        crv_minter_address = gauge_arth3crv.minter();
        crv_minter = IMinter(crv_minter_address);
    }

    function setCollatBorrowCap(uint256 _collat_borrow_cap)
        external
        onlyByOwnerOrGovernance
    {
        collat_borrow_cap = _collat_borrow_cap;
    }

    function setMaxArthOutstanding(uint256 _max_arth_outstanding)
        external
        onlyByOwnerOrGovernance
    {
        max_arth_outstanding = _max_arth_outstanding;
    }

    function setMinimumCollateralRatio(uint256 _min_cr)
        external
        onlyByOwnerOrGovernance
    {
        min_cr = _min_cr;
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyByOwnerOrGovernance
    {
        // Can only be triggered by owner or governance, not custodian
        // Tokens are sent to the custodian, as a sort of safeguard

        IERC20(tokenAddress).transfer(custodian_address, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /* ========== EVENTS ========== */

    event Recovered(address token, uint256 amount);
}
