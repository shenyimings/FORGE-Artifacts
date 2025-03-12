// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import './ARTHB.sol';
import '../Arth/IARTH.sol';
import '../ERC20/ERC20.sol';
import '../Math/SafeMath.sol';
import '../Governance/AccessControl.sol';
import '../Arth/IARTHController.sol';

/**
 *  Original code written by:
 *  - Travis Moore, Jason Huan, Same Kazemian, Sam Sun, Dennis.
 */
contract ArthBondIssuer is AccessControl {
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */
    enum DirectionChoice {BELOW_TO_PRICE_ARTH_IN, ABOVE_TO_PRICE}

    IARTH private ARTH;
    ArthBond private ARTHB;
    IARTHController private controller;

    address public ownerAddress;
    address public timelock_address;
    address public controller_address;

    uint256 public constant PRICE_PRECISION = 1e6;
    uint256 private constant PRICE_PRECISION_SQUARED = 1e12;
    uint256 private constant PRICE_PRECISION_SQRT = 1e3;

    // Minimum cooldown period before a new epoch, in seconds
    // Bonds should be redeemed during this time, or they risk being rebalanced with a new epoch
    uint256 public cooldown_period = 864000; // 10 days

    // Max ARTHB outstanding
    uint256 public max_arthb_outstanding = 1000000e18;

    // Target liquidity of ARTHB for the vAMM
    uint256 public target_liquidity_arthb = 500000e18;

    // Issuable ARTHB
    // This will be sold at the floor price until depleted, and bypass the vAMM
    uint256 public issuable_arthb = 80000e18;
    uint256 public issue_price = 750000;

    // Set fees, E6
    uint256 public issue_fee = 500; // 0.05% initially
    uint256 public buying_fee = 1500; // 0.15% initially
    uint256 public selling_fee = 1500; // 0.15% initially
    uint256 public redemptionFee = 500; // 0.05% initially

    // Epoch start and end times
    uint256 public epoch_start;
    uint256 public epoch_end;

    // Epoch length
    uint256 public epoch_length = 31536000; // 1 year

    // Initial discount rates per epoch, in E6
    uint256 public initial_discount = 200000; // 20% initially

    // Minimum collateral ratio
    uint256 public min_collateral_ratio = 850000;

    // Governance variables
    address public DEFAULT_ADMIN_ADDRESS;
    bytes32 public constant ISSUING_PAUSER = keccak256('ISSUING_PAUSER');
    bytes32 public constant BUYING_PAUSER = keccak256('BUYING_PAUSER');
    bytes32 public constant SELLING_PAUSER = keccak256('SELLING_PAUSER');
    bytes32 public constant REDEEMING_PAUSER = keccak256('REDEEMING_PAUSER');
    bool public issuingPaused = false;
    bool public buyingPaused = false;
    bool public sellingPaused = false;
    bool public redeemingPaused = false;

    // Virtual balances
    uint256 public vBal_ARTH;
    uint256 public vBal_ARTHB;

    /* ========== MODIFIERS ========== */

    modifier onlyByOwnerControllerOrGovernance() {
        require(
            msg.sender == ownerAddress ||
                msg.sender == timelock_address ||
                msg.sender == controller_address,
            'You are not the owner, controller, or the governance timelock'
        );
        _;
    }

    modifier onlyByOwnerOrTimelock() {
        require(
            msg.sender == ownerAddress || msg.sender == timelock_address,
            'You are not the owner or the governance timelock'
        );
        _;
    }

    modifier notIssuingPaused() {
        require(issuingPaused == false, 'Issuing is paused');
        _;
    }

    modifier notBuyingPaused() {
        require(buyingPaused == false, 'Buying is paused');
        _;
    }

    modifier notSellingPaused() {
        require(sellingPaused == false, 'Selling is paused');
        _;
    }

    modifier notRedeemingPaused() {
        require(redeemingPaused == false, 'Redeeming is paused');
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _arth_contract_address,
        address _arthb_contract_address,
        address _ownerAddress,
        address _timelock_address,
        address _controller_address
    ) {
        ARTH = IARTH(_arth_contract_address);
        ARTHB = ArthBond(_arthb_contract_address);
        ownerAddress = _ownerAddress;
        timelock_address = _timelock_address;
        controller_address = _controller_address;

        // Needed for initialization
        epoch_start = (block.timestamp).sub(cooldown_period).sub(epoch_length);
        epoch_end = (block.timestamp).sub(cooldown_period);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        DEFAULT_ADMIN_ADDRESS = _msgSender();
        grantRole(ISSUING_PAUSER, _ownerAddress);
        grantRole(ISSUING_PAUSER, _timelock_address);
        grantRole(ISSUING_PAUSER, _controller_address);
        grantRole(BUYING_PAUSER, _ownerAddress);
        grantRole(BUYING_PAUSER, _timelock_address);
        grantRole(BUYING_PAUSER, _controller_address);
        grantRole(SELLING_PAUSER, _ownerAddress);
        grantRole(SELLING_PAUSER, _timelock_address);
        grantRole(SELLING_PAUSER, _controller_address);
        grantRole(REDEEMING_PAUSER, _ownerAddress);
        grantRole(REDEEMING_PAUSER, _timelock_address);
        grantRole(REDEEMING_PAUSER, _controller_address);
    }

    /* ========== VIEWS ========== */

    // Returns some info
    function issuer_info()
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            bool,
            uint256,
            uint256
        )
    {
        return (
            issue_fee,
            buying_fee,
            selling_fee,
            redemptionFee,
            issuable_arthb,
            epoch_start,
            epoch_end,
            maximum_arthb_AMM_sellable_above_floor(),
            amm_spot_price(),
            floor_price(),
            isInEpoch(),
            isInCooldown(),
            cooldown_period,
            issue_price
        );
    }

    // Needed for the Arth contract to function without bricking
    function getCollateralGMUBalance()
        external
        pure
        returns (uint256 dummy_dollar_balance)
    {
        dummy_dollar_balance = uint256(1e18); // 1 nonexistant USDC
    }

    // Checks if the bond is in a maturity epoch
    function isInEpoch() public view returns (bool in_epoch) {
        in_epoch = ((block.timestamp >= epoch_start) &&
            (block.timestamp < epoch_end));
    }

    // Checks if the bond is in the cooldown period
    function isInCooldown() public view returns (bool in_cooldown) {
        in_cooldown = ((block.timestamp >= epoch_end) &&
            (block.timestamp < epoch_end.add(cooldown_period)));
    }

    // Liquidity balances for the floor price
    function getVirtualFloorLiquidityBalances()
        public
        view
        returns (uint256 arth_balance, uint256 arthb_balance)
    {
        arth_balance = target_liquidity_arthb.mul(floor_price()).div(
            PRICE_PRECISION
        );
        arthb_balance = target_liquidity_arthb;
    }

    // vAMM price for 1 ARTHB, in ARTH
    // The contract won't necessarily sell or buy at this price
    function amm_spot_price() public view returns (uint256 arthb_price) {
        arthb_price = vBal_ARTH.mul(PRICE_PRECISION).div(vBal_ARTHB);
    }

    // ARTHB floor price for 1 ARTHB, in ARTH
    // Will be used to help prevent someone from doing a huge arb with cheap bonds right before they mature
    // Also allows the vAMM to buy back cheap ARTHB under the floor and retire it, meaning less to pay back later at face value
    function floor_price() public view returns (uint256 floorPrice) {
        uint256 time_into_epoch = (block.timestamp).sub(epoch_start);
        floorPrice = (PRICE_PRECISION.sub(initial_discount)).add(
            initial_discount.mul(time_into_epoch).div(epoch_length)
        );
    }

    function initial_price() public view returns (uint256 initialPrice) {
        initialPrice = (PRICE_PRECISION.sub(initial_discount));
    }

    // How much ARTH is needed to buy out the remaining unissued ARTHB
    function arth_to_buy_out_issue() public view returns (uint256 arth_value) {
        uint256 arthb_fee_amt =
            issuable_arthb.mul(issue_fee).div(PRICE_PRECISION);
        arth_value = (issuable_arthb.add(arthb_fee_amt)).mul(issue_price).div(
            PRICE_PRECISION
        );
    }

    // Maximum amount of ARTHB you can sell into the vAMM at market prices before it hits the floor price and either cuts off
    // or sells at the floor price, dependingon how sellARTHBintoAMM is called
    // If the vAMM price is above the floor, you may sell ARTHB until doing so would push the price down to the floor
    // Will be 0 if the vAMM price is at or below the floor price
    function maximum_arthb_AMM_sellable_above_floor()
        public
        view
        returns (uint256 maximum_arthb_for_sell)
    {
        uint256 the_floor_price = floor_price();

        if (amm_spot_price() > the_floor_price) {
            maximum_arthb_for_sell = getBoundedIn(
                DirectionChoice.ABOVE_TO_PRICE,
                the_floor_price
            );
        } else {
            maximum_arthb_for_sell = 0;
        }
    }

    // Used for buying up to the issue price from below
    function arth_from_spot_to_issue()
        public
        view
        returns (uint256 arth_spot_to_issue)
    {
        if (amm_spot_price() < issue_price) {
            arth_spot_to_issue = getBoundedIn(
                DirectionChoice.BELOW_TO_PRICE_ARTH_IN,
                issue_price
            );
        } else {
            arth_spot_to_issue = 0;
        }
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    // Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // Uses constant product concept https://uniswap.org/docs/v2/core-concepts/swaps/
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 the_fee
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, 'ArthBondIssuer: INSUFFICIENT_INPUT_AMOUNT');
        require(
            reserveIn > 0 && reserveOut > 0,
            'ArthBondIssuer: INSUFFICIENT_LIQUIDITY'
        );
        uint256 amountInWithFee =
            amountIn.mul(uint256(PRICE_PRECISION).sub(the_fee));
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator =
            (reserveIn.mul(PRICE_PRECISION)).add(amountInWithFee);
        amountOut = numerator.div(denominator);
    }

    function getAmountOutNoFee(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut, 0);
    }

    function buyUnissuedARTHB(uint256 arth_in, uint256 arthb_out_min)
        public
        notIssuingPaused
        returns (uint256 arthb_out, uint256 arthb_fee_amt)
    {
        require(isInEpoch(), 'Not in an epoch');
        require(issuable_arthb > 0, 'No new ARTHB to issue');
        require(
            controller.getARTHPrice() < PRICE_PRECISION,
            'ARTH price must be less than $1'
        );
        require(
            controller.getGlobalCollateralRatio() >= min_collateral_ratio,
            'ARTH is already too undercollateralized'
        );

        // Issue at the issue_price or the floor_price, whichever is higher
        uint256 price_to_use = issue_price;
        {
            uint256 the_floor_price = floor_price();
            if (the_floor_price > issue_price) {
                price_to_use = the_floor_price;
            }
        }

        // Get the expected amount of ARTHB from the floor-priced portion
        arthb_out = arth_in.mul(PRICE_PRECISION).div(price_to_use);

        // Calculate and apply the normal buying fee
        arthb_fee_amt = arthb_out.mul(issue_fee).div(PRICE_PRECISION);

        // Apply the fee
        arthb_out = arthb_out.sub(arthb_fee_amt);

        // Check arthb_out_min
        require(
            arthb_out >= arthb_out_min,
            '[buyUnissuedARTHB arthb_out_min]: Slippage limit reached'
        );

        // Check the limit
        require(
            arthb_out <= issuable_arthb,
            'Trying to buy too many unissued bonds'
        );

        // Safety check
        require(
            ((ARTHB.totalSupply()).add(arthb_out)) <= max_arthb_outstanding,
            'New issue would exceed max_arthb_outstanding'
        );

        // Decrement the unissued amount
        issuable_arthb = issuable_arthb.sub(arthb_out);

        // Zero out precision-related crumbs if less than 1 ARTHB left
        if (issuable_arthb < uint256(1e18)) {
            issuable_arthb = 0;
        }

        // Burn ARTH from the sender. No vAMM balance change here
        ARTH.poolBurnFrom(msg.sender, arth_in);

        // Mint ARTHB to the sender. No vAMM balance change here
        ARTHB.issuer_mint(msg.sender, arthb_out);
    }

    function buyARTHBfromAMM(uint256 arth_in, uint256 arthb_out_min)
        external
        notBuyingPaused
        returns (uint256 arthb_out, uint256 arthb_fee_amt)
    {
        require(isInEpoch(), 'Not in an epoch');

        // Get the vAMM price
        uint256 spot_price = amm_spot_price();

        // Rebalance the vAMM if applicable
        // This may be the case if the floor price moved up slowly and nobody made any purchases for a while
        {
            if (spot_price < floor_price()) {
                _rebalance_AMM_ARTHB();
                _rebalance_AMM_ARTH_to_price(floor_price());
            }
        }

        // Calculate the ARTHB output
        arthb_out = getAmountOutNoFee(arth_in, vBal_ARTH, vBal_ARTHB);

        // Calculate and apply the normal buying fee
        arthb_fee_amt = arthb_out.mul(buying_fee).div(PRICE_PRECISION);

        // Apply the fee
        arthb_out = arthb_out.sub(arthb_fee_amt);

        // Check arthb_out_min
        require(
            arthb_out >= arthb_out_min,
            '[buyARTHBfromAMM arthb_out_min]: Slippage limit reached'
        );

        // Safety check
        require(
            ((ARTHB.totalSupply()).add(arthb_out)) <= max_arthb_outstanding,
            'New issue would exceed max_arthb_outstanding'
        );

        // Burn ARTH from the sender and increase the virtual balance
        // ARTH.burnFrom(msg.sender, arth_in);
        vBal_ARTH = vBal_ARTH.add(arth_in);

        // Mint ARTHB to the sender and decrease the virtual balance
        ARTHB.issuer_mint(msg.sender, arthb_out);
        vBal_ARTHB = vBal_ARTHB.sub(arthb_out);

        // vAMM will burn ARTH if the effective sale price is above 1. It is essentially free ARTH and a protocol-level profit
        {
            uint256 effective_sale_price =
                arth_in.mul(PRICE_PRECISION).div(arthb_out);
            if (effective_sale_price > PRICE_PRECISION) {
                // Rebalance to $1
                _rebalance_AMM_ARTHB();
                _rebalance_AMM_ARTH_to_price(PRICE_PRECISION);
            }
        }
    }

    function sellARTHBintoAMM(uint256 arthb_in, uint256 ARTHOutMin)
        external
        notSellingPaused
        returns (
            uint256 arthb_bought_above_floor,
            uint256 arthb_sold_under_floor,
            uint256 arth_out,
            uint256 arth_fee_amt
        )
    {
        require(isInEpoch(), 'Not in an epoch');

        arthb_bought_above_floor = arthb_in;
        arthb_sold_under_floor = 0;

        // The vAMM will buy back ARTHB at market rates in all cases
        // However, any ARTHB bought back under the floor price will be burned
        uint256 max_above_floor_sellable_arthb =
            maximum_arthb_AMM_sellable_above_floor();
        if (arthb_in >= max_above_floor_sellable_arthb) {
            arthb_bought_above_floor = max_above_floor_sellable_arthb;
            arthb_sold_under_floor = arthb_in.sub(
                max_above_floor_sellable_arthb
            );
        } else {
            // no change to arthb_bought_above_floor
            arthb_sold_under_floor = 0;
        }

        // Get the expected amount of ARTH from above the floor
        uint256 arth_out_above_floor = 0;
        if (arthb_bought_above_floor > 0) {
            arth_out_above_floor = getAmountOutNoFee(
                arthb_bought_above_floor,
                vBal_ARTHB,
                vBal_ARTH
            );

            // Apply the normal selling fee to this portion
            uint256 fee_above_floor =
                arth_out_above_floor.mul(selling_fee).div(PRICE_PRECISION);
            arth_out_above_floor = arth_out_above_floor.sub(fee_above_floor);

            // Informational for return values
            arth_fee_amt += fee_above_floor;
            arth_out += arth_out_above_floor;
        }

        // Get the expected amount of ARTH from below the floor
        // Need to adjust the balances virtually for this
        uint256 arth_out_under_floor = 0;
        if (arthb_sold_under_floor > 0) {
            // Get the virtual amount under the floor
            (
                uint256 arth_floor_balance_virtual,
                uint256 arthb_floor_balance_virtual
            ) = getVirtualFloorLiquidityBalances();
            arth_out_under_floor = getAmountOutNoFee(
                arthb_sold_under_floor,
                arthb_floor_balance_virtual.add(arthb_bought_above_floor),
                arth_floor_balance_virtual.sub(arth_out_above_floor)
            );

            // Apply the normal selling fee to this portion
            uint256 fee_below_floor =
                arth_out_under_floor.mul(selling_fee).div(PRICE_PRECISION);
            arth_out_under_floor = arth_out_under_floor.sub(fee_below_floor);

            // Informational for return values
            arth_fee_amt += fee_below_floor;
            arth_out += arth_out_under_floor;
        }

        // Check ARTHOutMin
        require(
            arth_out >= ARTHOutMin,
            '[sellARTHBintoAMM ARTHOutMin]: Slippage limit reached'
        );

        // Take ARTHB from the sender and increase the virtual balance
        ARTHB.burnFrom(msg.sender, arthb_in);
        vBal_ARTHB = vBal_ARTHB.add(arthb_in);

        // Give ARTH to sender from the vAMM and decrease the virtual balance
        ARTH.poolMint(msg.sender, arth_out);
        vBal_ARTH = vBal_ARTH.sub(arth_out);

        // If any ARTHB was sold under the floor price, retire / burn it and rebalance the pool
        // This is less ARTHB that will have to be redeemed at full value later and is essentially a protocol-level profit
        if (arthb_sold_under_floor > 0) {
            // Rebalance to the floor
            _rebalance_AMM_ARTHB();
            _rebalance_AMM_ARTH_to_price(floor_price());
        }
    }

    function redeemARTHB(uint256 arthb_in)
        external
        notRedeemingPaused
        returns (uint256 arth_out, uint256 arth_fee)
    {
        require(!isInEpoch(), 'Not in the cooldown period or outside an epoch');

        // Burn ARTHB from the sender
        ARTHB.burnFrom(msg.sender, arthb_in);

        // Give 1 ARTH per 1 ARTHB, minus the redemption fee
        arth_fee = arthb_in.mul(redemptionFee).div(PRICE_PRECISION);
        arth_out = arthb_in.sub(arth_fee);

        // Give the ARTH to the redeemer
        ARTH.poolMint(msg.sender, arth_out);

        emit ARTHB_Redeemed(msg.sender, arthb_in, arth_out);
    }

    /* ========== RESTRICTED INTERNAL FUNCTIONS ========== */

    function _rebalance_AMM_ARTH_to_price(uint256 rebalance_price) internal {
        // Safety checks
        require(rebalance_price <= PRICE_PRECISION, 'Rebalance price too high');
        require(
            rebalance_price >= (PRICE_PRECISION.sub(initial_discount)),
            'Rebalance price too low'
        );

        uint256 arth_required =
            target_liquidity_arthb.mul(rebalance_price).div(PRICE_PRECISION);
        if (arth_required > vBal_ARTH) {
            // Virtually add the deficiency
            vBal_ARTH = vBal_ARTH.add(arth_required.sub(vBal_ARTH));
        } else if (arth_required < vBal_ARTH) {
            // Virtually subtract the excess
            vBal_ARTH = vBal_ARTH.sub(vBal_ARTH.sub(arth_required));
        } else if (arth_required == vBal_ARTH) {
            // Do nothing
        }
    }

    function _rebalance_AMM_ARTHB() internal {
        uint256 arthb_required = target_liquidity_arthb;
        if (arthb_required > vBal_ARTHB) {
            // Virtually add the deficiency
            vBal_ARTHB = vBal_ARTHB.add(arthb_required.sub(vBal_ARTHB));
        } else if (arthb_required < vBal_ARTHB) {
            // Virtually subtract the excess
            vBal_ARTHB = vBal_ARTHB.sub(vBal_ARTHB.sub(arthb_required));
        } else if (arthb_required == vBal_ARTHB) {
            // Do nothing
        }

        // Quick safety check
        require(
            ((ARTHB.totalSupply()).add(issuable_arthb)) <=
                max_arthb_outstanding,
            'Rebalance would exceed max_arthb_outstanding'
        );
    }

    function getBoundedIn(DirectionChoice choice, uint256 the_price)
        internal
        view
        returns (uint256 bounded_amount)
    {
        if (choice == DirectionChoice.BELOW_TO_PRICE_ARTH_IN) {
            uint256 numerator =
                sqrt(vBal_ARTH).mul(sqrt(vBal_ARTHB)).mul(PRICE_PRECISION_SQRT);
            // The "price" here needs to be inverted
            uint256 denominator =
                sqrt((PRICE_PRECISION_SQUARED).div(the_price));
            bounded_amount = numerator.div(denominator).sub(vBal_ARTH);
        } else if (choice == DirectionChoice.ABOVE_TO_PRICE) {
            uint256 numerator =
                sqrt(vBal_ARTH).mul(sqrt(vBal_ARTHB)).mul(PRICE_PRECISION_SQRT);
            uint256 denominator = sqrt(the_price);
            bounded_amount = numerator.div(denominator).sub(vBal_ARTHB);
        }
    }

    /* ========== RESTRICTED EXTERNAL FUNCTIONS ========== */

    // Allows for expanding the liquidity mid-epoch
    // The expansion must occur at the current vAMM price
    function expand_AMM_liquidity(
        uint256 arthb_expansion_amount,
        bool do_rebalance
    ) external onlyByOwnerControllerOrGovernance {
        require(isInEpoch(), 'Not in an epoch');
        require(
            controller.getGlobalCollateralRatio() >= min_collateral_ratio,
            'ARTH is already too undercollateralized'
        );

        // Expand the ARTHB target liquidity
        target_liquidity_arthb = target_liquidity_arthb.add(
            arthb_expansion_amount
        );

        // Optionally do the rebalance. If not, it will be done at an applicable time in one of the buy / sell functions
        if (do_rebalance) {
            rebalance_AMM_liquidity_to_price(amm_spot_price());
        }
    }

    // Allows for contracting the liquidity mid-epoch
    // The expansion must occur at the current vAMM price
    function contract_AMM_liquidity(
        uint256 arthb_contraction_amount,
        bool do_rebalance
    ) external onlyByOwnerControllerOrGovernance {
        require(isInEpoch(), 'Not in an epoch');
        require(
            controller.getGlobalCollateralRatio() >= min_collateral_ratio,
            'ARTH is already too undercollateralized'
        );

        // Expand the ARTHB target liquidity
        target_liquidity_arthb = target_liquidity_arthb.sub(
            arthb_contraction_amount
        );

        // Optionally do the rebalance. If not, it will be done at an applicable time in one of the buy / sell functions
        if (do_rebalance) {
            rebalance_AMM_liquidity_to_price(amm_spot_price());
        }
    }

    // Rebalance vAMM to a desired price
    function rebalance_AMM_liquidity_to_price(uint256 rebalance_price)
        public
        onlyByOwnerControllerOrGovernance
    {
        // Rebalance the ARTHB
        _rebalance_AMM_ARTHB();

        // Rebalance the ARTH
        _rebalance_AMM_ARTH_to_price(rebalance_price);
    }

    // Starts a new epoch and rebalances the vAMM
    function startNewEpoch() external onlyByOwnerControllerOrGovernance {
        require(!isInEpoch(), 'Already in an existing epoch');
        require(
            !isInCooldown(),
            'Bonds are currently settling in the cooldown'
        );

        // Rebalance the vAMM liquidity
        rebalance_AMM_liquidity_to_price(PRICE_PRECISION.sub(initial_discount));

        // Set state variables
        epoch_start = block.timestamp;
        epoch_end = epoch_start.add(epoch_length);

        emit ARTHB_EpochStarted(
            msg.sender,
            epoch_start,
            epoch_end,
            epoch_length,
            initial_discount,
            max_arthb_outstanding
        );
    }

    function toggleIssuing() external {
        require(hasRole(ISSUING_PAUSER, msg.sender));
        issuingPaused = !issuingPaused;
    }

    function toggleBuying() external {
        require(hasRole(BUYING_PAUSER, msg.sender));
        buyingPaused = !buyingPaused;
    }

    function toggleSelling() external {
        require(hasRole(SELLING_PAUSER, msg.sender));
        sellingPaused = !sellingPaused;
    }

    function toggleRedeeming() external {
        require(hasRole(REDEEMING_PAUSER, msg.sender));
        redeemingPaused = !redeemingPaused;
    }

    function setMaxARTHBOutstanding(uint256 _max_arthb_outstanding)
        external
        onlyByOwnerControllerOrGovernance
    {
        max_arthb_outstanding = _max_arthb_outstanding;
    }

    function setTargetLiquidity(
        uint256 _target_liquidity_arthb,
        bool _rebalance_vAMM
    ) external onlyByOwnerControllerOrGovernance {
        target_liquidity_arthb = _target_liquidity_arthb;
        if (_rebalance_vAMM) {
            rebalance_AMM_liquidity_to_price(amm_spot_price());
        }
    }

    function clearIssuableARTHB() external onlyByOwnerControllerOrGovernance {
        issuable_arthb = 0;
        issue_price = PRICE_PRECISION;
    }

    function setIssuableARTHB(uint256 _issuable_arthb, uint256 _issue_price)
        external
        onlyByOwnerControllerOrGovernance
    {
        if (_issuable_arthb > issuable_arthb) {
            require(
                ((ARTHB.totalSupply()).add(_issuable_arthb)) <=
                    max_arthb_outstanding,
                'New issue would exceed max_arthb_outstanding'
            );
        }
        issuable_arthb = _issuable_arthb;
        issue_price = _issue_price;
    }

    function setFees(
        uint256 _issue_fee,
        uint256 _buying_fee,
        uint256 _selling_fee,
        uint256 _redemptionFee
    ) external onlyByOwnerControllerOrGovernance {
        issue_fee = _issue_fee;
        buying_fee = _buying_fee;
        selling_fee = _selling_fee;
        redemptionFee = _redemptionFee;
    }

    function setCooldownPeriod(uint256 _cooldown_period)
        external
        onlyByOwnerControllerOrGovernance
    {
        cooldown_period = _cooldown_period;
    }

    function setEpochLength(uint256 _epoch_length)
        external
        onlyByOwnerControllerOrGovernance
    {
        epoch_length = _epoch_length;
    }

    function setMinCollateralRatio(uint256 _min_collateral_ratio)
        external
        onlyByOwnerControllerOrGovernance
    {
        min_collateral_ratio = _min_collateral_ratio;
    }

    function setInitialDiscount(uint256 _initial_discount, bool _rebalance_AMM)
        external
        onlyByOwnerControllerOrGovernance
    {
        initial_discount = _initial_discount;
        if (_rebalance_AMM) {
            rebalance_AMM_liquidity_to_price(
                PRICE_PRECISION.sub(initial_discount)
            );
        }
    }

    /* ========== HIGHLY RESTRICTED EXTERNAL FUNCTIONS [Owner and Timelock only]  ========== */

    function setController(address _controller_address)
        external
        onlyByOwnerOrTimelock
    {
        controller_address = _controller_address;
    }

    function setTimelock(address new_timelock) external onlyByOwnerOrTimelock {
        timelock_address = new_timelock;
    }

    function setOwner(address _ownerAddress) external onlyByOwnerOrTimelock {
        ownerAddress = _ownerAddress;
    }

    function emergencyRecoverERC20(
        address destination_address,
        address tokenAddress,
        uint256 tokenAmount
    ) external onlyByOwnerOrTimelock {
        ERC20(tokenAddress).transfer(destination_address, tokenAmount);
        emit Recovered(tokenAddress, destination_address, tokenAmount);
    }

    /* ========== PURE FUNCTIONS ========== */

    // Babylonian method
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }

    /* ========== EVENTS ========== */

    event Recovered(address token, address to, uint256 amount);

    // Track bond redeeming
    event ARTHB_Redeemed(
        address indexed from,
        uint256 arthb_amount,
        uint256 arth_out
    );
    event ARTHB_EpochStarted(
        address indexed from,
        uint256 _epoch_start,
        uint256 _epoch_end,
        uint256 _epoch_length,
        uint256 _initial_discount,
        uint256 _max_arthb_amount
    );
}
