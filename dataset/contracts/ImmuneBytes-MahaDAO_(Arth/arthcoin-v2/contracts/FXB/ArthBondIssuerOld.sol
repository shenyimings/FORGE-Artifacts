// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import './ARTHB.sol';
import '../Arth/IARTH.sol';
import '../ERC20/ERC20.sol';
import '../Math/SafeMath.sol';
import '../Governance/AccessControl.sol';

/**
 *  Original code written by:
 *  - Travis Moore, Jason Huan, Same Kazemian, Sam Sun.
 */
contract ArthBondIssuerOld is AccessControl {
    // using SafeMath for uint256;
    // /* ========== STATE VARIABLES ========== */
    // enum DirectionChoice { BELOW_TO_FLOOR_ARTH_IN, ABOVE_TO_FLOOR }
    // ARTHStablecoin private ARTH;
    // ArthBond private ARTHB;
    // address public ownerAddress;
    // address public timelock_address;
    // uint256 private constant PRICE_PRECISION = 1e6;
    // // Minimum cooldown period before a new epoch, in seconds
    // // Bonds should be redeemed during this time, or they risk being rebalanced with a new epoch
    // uint256 public cooldown_period = 864000; // 10 days
    // // Max ARTHB outstanding
    // uint256 public max_arthb_outstanding = uint256(1000000e18);
    // // Target liquidity of ARTHB for the AMM pool
    // uint256 public target_liquidity_arthb = uint256(500000e18);
    // // Issuable ARTHB
    // // This will be sold at the floor price until depleted, and bypass the AMM
    // uint256 public issuable_arthb = uint256(80000e18);
    // // Set fees, E6
    // uint256 public issue_fee = 500; // 0.05% initially
    // uint256 public buying_fee = 1500; // 0.15% initially
    // uint256 public selling_fee = 1500; // 0.15% initially
    // uint256 public redemptionFee = 500; // 0.05% initially
    // // Epoch start and end times
    // uint256 public epoch_start;
    // uint256 public epoch_end;
    // // Epoch length
    // uint256 public epoch_length = 31536000; // 1 year
    // // Initial discount rates per epoch, in E6
    // uint256 public default_initial_discount = 200000; // 20% initially
    // uint256 public failsafe_max_initial_discount = 300000; // 30%. Failsafe max discount rate, in case _calcInitialDiscount() fails
    // // Governance variables
    // address public DEFAULT_ADMIN_ADDRESS;
    // bytes32 public constant ISSUING_PAUSER = keccak256("ISSUING_PAUSER");
    // bytes32 public constant BUYING_PAUSER = keccak256("BUYING_PAUSER");
    // bytes32 public constant SELLING_PAUSER = keccak256("SELLING_PAUSER");
    // bytes32 public constant REDEEMING_PAUSER = keccak256("REDEEMING_PAUSER");
    // bytes32 public constant DEFAULT_DISCOUNT_TOGGLER = keccak256("DEFAULT_DISCOUNT_TOGGLER");
    // bool public issuingPaused = false;
    // bool public buyingPaused = false;
    // bool public sellingPaused = false;
    // bool public redeemingPaused = false;
    // bool public useDefaultInitialDiscount = false;
    // /* ========== MODIFIERS ========== */
    // modifier onlyByOwnerOrGovernance() {
    //     require(msg.sender == timelock_address || msg.sender == ownerAddress, "You are not the owner or the governance timelock");
    //     _;
    // }
    // modifier notIssuingPaused() {
    //     require(issuingPaused == false, "Issuing is paused");
    //     _;
    // }
    // modifier notBuyingPaused() {
    //     require(buyingPaused == false, "Buying is paused");
    //     _;
    // }
    // modifier notSellingPaused() {
    //     require(sellingPaused == false, "Selling is paused");
    //     _;
    // }
    // modifier notRedeemingPaused() {
    //     require(redeemingPaused == false, "Redeeming is paused");
    //     _;
    // }
    // /* ========== CONSTRUCTOR ========== */
    // constructor(
    //     address _arth_contract_address,
    //     address _arthb_contract_address,
    //     address _ownerAddress,
    //     address _timelock_address,
    //     address _custodian_address
    // ) public {
    //     ARTH = ARTHStablecoin(_arth_contract_address);
    //     ARTHB = ArthBond(_arthb_contract_address);
    //     ownerAddress = _ownerAddress;
    //     timelock_address = _timelock_address;
    //     // Needed for initialization
    //     epoch_start = (block.timestamp).sub(cooldown_period).sub(epoch_length);
    //     epoch_end = (block.timestamp).sub(cooldown_period);
    //     _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    //     DEFAULT_ADMIN_ADDRESS = _msgSender();
    //     grantRole(ISSUING_PAUSER, _ownerAddress);
    //     grantRole(ISSUING_PAUSER, _timelock_address);
    //     grantRole(BUYING_PAUSER, _ownerAddress);
    //     grantRole(BUYING_PAUSER, _timelock_address);
    //     grantRole(SELLING_PAUSER, _ownerAddress);
    //     grantRole(SELLING_PAUSER, _timelock_address);
    //     grantRole(REDEEMING_PAUSER, _ownerAddress);
    //     grantRole(REDEEMING_PAUSER, _timelock_address);
    //     grantRole(DEFAULT_DISCOUNT_TOGGLER, _ownerAddress);
    //     grantRole(DEFAULT_DISCOUNT_TOGGLER, _timelock_address);
    // }
    // /* ========== VIEWS ========== */
    // // Returns some info
    // function issuer_info() public view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool, bool, uint256) {
    //     return (
    //         issue_fee,
    //         buying_fee,
    //         selling_fee,
    //         redemptionFee,
    //         issuable_arthb,
    //         epoch_start,
    //         epoch_end,
    //         maximum_arthb_AMM_sellable_above_floor(),
    //         amm_spot_price(),
    //         floor_price(),
    //         isInEpoch(),
    //         isInCooldown(),
    //         cooldown_period
    //     );
    // }
    // // Needed for the Arth contract to function without bricking
    // function getCollateralGMUBalance() external view returns (uint256 dummy_dollar_balance) {
    //     dummy_dollar_balance =  uint256(1e18); // 1 nonexistant USDC
    // }
    // // Checks if the bond is in a maturity epoch
    // function isInEpoch() public view returns (bool in_epoch) {
    //     in_epoch = ((block.timestamp >= epoch_start) && (block.timestamp < epoch_end));
    // }
    // // Checks if the bond is in the cooldown period
    // function isInCooldown() public view returns (bool in_cooldown) {
    //     in_cooldown = ((block.timestamp >= epoch_end) && (block.timestamp < epoch_end.add(cooldown_period)));
    // }
    // // Calculates ARTHB outside the contract
    // function ARTHB_Outside_Contract() public view returns (uint256 arthb_outside_contract) {
    //     arthb_outside_contract = (ARTHB.totalSupply()).sub(ARTHB.balanceOf(address(this)));
    // }
    // // Algorithmically calculated optimal initial discount rate
    // function algorithmicInitialDiscount() public view returns (uint256 initial_discount) {
    //     // TODO: Some fancy algorithm
    //     // Perhaps in V2
    //     initial_discount = default_initial_discount;
    // }
    // // Liquidity balances for the floor price
    // function getVirtualFloorLiquidityBalances() public view returns (uint256 arth_balance, uint256 arthb_balance) {
    //     arth_balance = target_liquidity_arthb.mul(floor_price()).div(PRICE_PRECISION);
    //     arthb_balance = target_liquidity_arthb;
    // }
    // // AMM price for 1 ARTHB, in ARTH
    // // The contract won't necessarily sell or buy at this price
    // function amm_spot_price() public view returns (uint256 arthb_price) {
    //     arthb_price = getAmountOutNoFee(uint256(1e6), ARTHB.balanceOf(address(this)), ARTH.balanceOf(address(this)));
    // }
    // // ARTHB floor price for 1 ARTHB, in ARTH
    // // Will be used to help prevent someone from doing a huge arb with cheap bonds right before they mature
    // // Also allows the AMM to buy back cheap ARTHB under the floor and retire it, meaning less to pay back later at face value
    // function floor_price() public view returns (uint256 floor_price) {
    //     uint256 time_into_epoch = (block.timestamp).sub(epoch_start);
    //     uint256 initial_discount = getInitialDiscount();
    //     floor_price = (PRICE_PRECISION.sub(initial_discount)).add(initial_discount.mul(time_into_epoch).div(epoch_length));
    // }
    // function initial_price() public view returns (uint256 initial_price) {
    //     initial_price = (PRICE_PRECISION.sub(getInitialDiscount()));
    // }
    // function issuable_arthb_value_in_arth() public view returns (uint256 arth_value) {
    //     arth_value = issuable_arthb.mul(floor_price()).div(PRICE_PRECISION);
    // }
    // function getInitialDiscount() public view returns (uint256 initial_discount) {
    //     if (useDefaultInitialDiscount){
    //         initial_discount = default_initial_discount;
    //     }
    //     else {
    //         initial_discount = algorithmicInitialDiscount();
    //     }
    // }
    // // Maximum amount of ARTHB you can sell into the AMM at market prices before it hits the floor price and either cuts off
    // // or sells at the floor price, dependingon how sellARTHBintoAMM is called
    // // If the AMM price is above the floor, you may sell ARTHB until doing so would push the price down to the floor
    // // Will be 0 if the AMM price is at or below the floor price
    // function maximum_arthb_AMM_sellable_above_floor() public view returns (uint256 maximum_arthb_for_sell) {
    //     uint256 the_floor_price = floor_price();
    //     if (amm_spot_price() > the_floor_price){
    //         maximum_arthb_for_sell = getBoundedIn(DirectionChoice.ABOVE_TO_FLOOR, the_floor_price);
    //     }
    //     else {
    //         maximum_arthb_for_sell = 0;
    //     }
    // }
    // /* ========== PUBLIC FUNCTIONS ========== */
    // // Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // // Uses constant product concept https://uniswap.org/docs/v2/core-concepts/swaps/
    // function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint the_fee) public view returns (uint amountOut) {
    //     require(amountIn > 0, 'ArthBondIssuer: INSUFFICIENT_INPUT_AMOUNT');
    //     require(reserveIn > 0 && reserveOut > 0, 'ArthBondIssuer: INSUFFICIENT_LIQUIDITY');
    //     uint amountInWithFee = amountIn.mul(uint(1e6).sub(the_fee));
    //     uint numerator = amountInWithFee.mul(reserveOut);
    //     uint denominator = (reserveIn.mul(1e6)).add(amountInWithFee);
    //     amountOut = numerator / denominator;
    // }
    // function getAmountOutNoFee(uint amountIn, uint reserveIn, uint reserveOut) public view returns (uint amountOut) {
    //     amountOut = getAmountOut(amountIn, reserveIn, reserveOut, 0);
    // }
    // function buyUnissuedARTHB(uint256 arth_amount, uint256 arthb_out_min) external notIssuingPaused returns (uint256 arthb_out, uint256 arthb_fee_amt) {
    //     require(isInEpoch(), 'Not in an epoch');
    //     require(issuable_arthb > 0, 'No new ARTHB to issue');
    //     // Get the floor price
    //     uint256 the_floor_price = floor_price();
    //     // Get the expected amount of ARTHB from the floor-priced portion
    //     arthb_out = arth_amount.mul(PRICE_PRECISION).div(the_floor_price);
    //     // Calculate and apply the normal buying fee
    //     arthb_fee_amt = arthb_out.mul(issue_fee).div(PRICE_PRECISION);
    //     // Apply the fee
    //     arthb_out = arthb_out.sub(arthb_fee_amt);
    //     // Check arthb_out_min
    //     require(arthb_out >= arthb_out_min, "[buyUnissuedARTHB arthb_out_min]: Slippage limit reached");
    //     // Check the limit
    //     require(arthb_out <= issuable_arthb, 'Trying to buy too many unissued bonds');
    //     // Decrement the unissued amount
    //     issuable_arthb = issuable_arthb.sub(arthb_out);
    //     // Burn ARTH from the sender
    //     ARTH.poolBurnFrom(msg.sender, arth_amount);
    //     // Mint ARTHB to the sender
    //     ARTHB.issuer_mint(msg.sender, arthb_out);
    // }
    // function buyARTHBfromAMM(uint256 arth_amount, uint256 arthb_out_min) external notBuyingPaused returns (uint256 arthb_out, uint256 arthb_fee_amt) {
    //     require(isInEpoch(), 'Not in an epoch');
    //     // Rebalance the AMM if applicable
    //     // This may be the case if the floor price moved up slowly and nobody made any purchases for a while
    //     {
    //         if (amm_spot_price() < floor_price()){
    //             _rebalance_AMM_ARTHB();
    //             _rebalance_AMM_ARTH_to_price(floor_price());
    //         }
    //     }
    //     // Calculate the ARTHB output
    //     arthb_out = arthb_out = getAmountOutNoFee(arth_amount, ARTH.balanceOf(address(this)), ARTHB.balanceOf(address(this)));
    //     // Calculate and apply the normal buying fee
    //     arthb_fee_amt = arthb_out.mul(buying_fee).div(PRICE_PRECISION);
    //     // Apply the fee
    //     arthb_out = arthb_out.sub(arthb_fee_amt);
    //     // Check arthb_out_min
    //     require(arthb_out >= arthb_out_min, "[buyARTHBfromAMM arthb_out_min]: Slippage limit reached");
    //     // Take ARTH from the sender
    //     ARTH.transferFrom(msg.sender, address(this), arth_amount);
    //     // Give ARTHB to the sender
    //     ARTHB.transfer(msg.sender, arthb_out);
    //     // AMM will burn ARTH if the effective sale price is above 1. It is essentially free ARTH and a protocol-level profit
    //     {
    //         uint256 effective_sale_price = arth_amount.mul(PRICE_PRECISION).div(arthb_out);
    //         if(effective_sale_price > PRICE_PRECISION){
    //             // Rebalance to $1
    //             _rebalance_AMM_ARTHB();
    //             _rebalance_AMM_ARTH_to_price(PRICE_PRECISION);
    //         }
    //     }
    // }
    // function sellARTHBintoAMM(uint256 arthb_amount, uint256 ARTHOutMin) external notSellingPaused returns (uint256 arthb_bought_above_floor, uint256 arthb_sold_under_floor, uint256 arth_out, uint256 arth_fee_amt) {
    //     require(isInEpoch(), 'Not in an epoch');
    //     arthb_bought_above_floor = arthb_amount;
    //     arthb_sold_under_floor = 0;
    //     // The AMM will buy back ARTHB at market rates in all cases
    //     // However, any ARTHB bought back under the floor price will be burned
    //     uint256 max_above_floor_sellable_arthb = maximum_arthb_AMM_sellable_above_floor();
    //     if(arthb_amount >= max_above_floor_sellable_arthb){
    //         arthb_bought_above_floor = max_above_floor_sellable_arthb;
    //         arthb_sold_under_floor = arthb_amount.sub(max_above_floor_sellable_arthb);
    //     }
    //     else {
    //         // no change to arthb_bought_above_floor
    //         arthb_sold_under_floor = 0;
    //     }
    //     // Get the expected amount of ARTH from above the floor
    //     uint256 arth_out_above_floor = 0;
    //     if (arthb_bought_above_floor > 0){
    //         arth_out_above_floor = getAmountOutNoFee(arthb_bought_above_floor, ARTHB.balanceOf(address(this)), ARTH.balanceOf(address(this)));
    //         // Apply the normal selling fee to this portion
    //         uint256 fee_above_floor = arth_out_above_floor.mul(selling_fee).div(PRICE_PRECISION);
    //         arth_out_above_floor = arth_out_above_floor.sub(fee_above_floor);
    //         // Informational for return values
    //         arth_fee_amt += fee_above_floor;
    //         arth_out += arth_out_above_floor;
    //     }
    //     // Get the expected amount of ARTH from below the floor
    //     // Need to adjust the balances virtually for this
    //     uint256 arth_out_under_floor = 0;
    //     if (arthb_sold_under_floor > 0){
    //         // Get the virtual amount under the floor
    //         (uint256 arth_floor_balance_virtual, uint256 arthb_floor_balance_virtual) = getVirtualFloorLiquidityBalances();
    //         arth_out_under_floor = getAmountOutNoFee(arthb_sold_under_floor, arthb_floor_balance_virtual.add(arthb_bought_above_floor), arth_floor_balance_virtual.sub(arth_out_above_floor));
    //         // Apply the normal selling fee to this portion
    //         uint256 fee_below_floor = arth_out_under_floor.mul(selling_fee).div(PRICE_PRECISION);
    //         arth_out_under_floor = arth_out_under_floor.sub(fee_below_floor);
    //         // Informational for return values
    //         arth_fee_amt += fee_below_floor;
    //         arth_out += arth_out_under_floor;
    //     }
    //     // Check ARTHOutMin
    //     require(arth_out >= ARTHOutMin, "[sellARTHBintoAMM ARTHOutMin]: Slippage limit reached");
    //     // Take ARTHB from the sender
    //     ARTHB.transferFrom(msg.sender, address(this), arthb_amount);
    //     // Give ARTH to sender from the AMM pool
    //     ARTH.transfer(msg.sender, arth_out);
    //     // If any ARTHB was sold under the floor price, retire / burn it and rebalance the pool
    //     // This is less ARTHB that will have to be redeemed at full value later and is essentially a protocol-level profit
    //     if (arthb_sold_under_floor > 0){
    //         // Rebalance to the floor
    //         _rebalance_AMM_ARTHB();
    //         _rebalance_AMM_ARTH_to_price(floor_price());
    //     }
    // }
    // function redeemARTHB(uint256 arthb_amount) external notRedeemingPaused returns (uint256 arth_out, uint256 arth_fee) {
    //     require(isInCooldown(), 'Not in the cooldown period');
    //     // Take ARTHB from the sender
    //     ARTHB.transferFrom(msg.sender, address(this), arthb_amount);
    //     // Give 1 ARTH per 1 ARTHB, minus the redemption fee
    //     arth_fee = arthb_amount.mul(redemptionFee).div(PRICE_PRECISION);
    //     arth_out = arthb_amount.sub(arth_fee);
    //     // Give the ARTH to the redeemer
    //     ARTH.poolMint(msg.sender, arth_out);
    //     emit ARTHB_Redeemed(msg.sender, arthb_amount, arth_out);
    // }
    // /* ========== RESTRICTED INTERNAL FUNCTIONS ========== */
    // function _rebalance_AMM_ARTH_to_price(uint256 rebalance_price) internal {
    //     // Safety checks
    //     require(rebalance_price <= PRICE_PRECISION, "Rebalance price too high");
    //     require(rebalance_price >= (PRICE_PRECISION.sub(failsafe_max_initial_discount)), "Rebalance price too low");
    //     uint256 arth_required = target_liquidity_arthb.mul(rebalance_price).div(PRICE_PRECISION);
    //     uint256 arth_inside_contract = ARTH.balanceOf(address(this));
    //     if (arth_required > arth_inside_contract){
    //         // Mint the deficiency
    //         ARTH.poolMint(address(this), arth_required.sub(arth_inside_contract));
    //     }
    //     else if (arth_required < arth_inside_contract){
    //         // Burn the excess
    //         ARTH.burn(arth_inside_contract.sub(arth_required));
    //     }
    //     else if (arth_required == arth_inside_contract){
    //         // Do nothing
    //     }
    // }
    // function _rebalance_AMM_ARTHB() internal {
    //     uint256 arthb_required = target_liquidity_arthb;
    //     uint256 arthb_inside_contract = ARTHB.balanceOf(address(this));
    //     if (arthb_required > arthb_inside_contract){
    //         // Mint the deficiency
    //         ARTHB.issuer_mint(address(this), arthb_required.sub(arthb_inside_contract));
    //     }
    //     else if (arthb_required < arthb_inside_contract){
    //         // Burn the excess
    //         ARTHB.burn(arthb_inside_contract.sub(arthb_required));
    //     }
    //     else if (arthb_required == arthb_inside_contract){
    //         // Do nothing
    //     }
    //     // Quick safety check
    //     require(((ARTHB.totalSupply()).add(issuable_arthb)) <= max_arthb_outstanding, "Rebalance would exceed max_arthb_outstanding");
    // }
    // /* ========== RESTRICTED EXTERNAL FUNCTIONS ========== */
    // // Allows for expanding the liquidity mid-epoch
    // // The expansion must occur at the current AMM price
    // function expand_AMM_liquidity(uint256 arthb_expansion_amount) external onlyByOwnerOrGovernance {
    //     require(isInEpoch(), 'Not in an epoch');
    //     // Expand the ARTHB target liquidity
    //     target_liquidity_arthb = target_liquidity_arthb.add(arthb_expansion_amount);
    //     // Do the rebalance
    //     rebalance_AMM_liquidity_to_price(amm_spot_price());
    // }
    // // Allows for contracting the liquidity mid-epoch
    // // The expansion must occur at the current AMM price
    // function contract_AMM_liquidity(uint256 arthb_contraction_amount) external onlyByOwnerOrGovernance {
    //     require(isInEpoch(), 'Not in an epoch');
    //     // Expand the ARTHB target liquidity
    //     target_liquidity_arthb = target_liquidity_arthb.sub(arthb_contraction_amount);
    //     // Do the rebalance
    //     rebalance_AMM_liquidity_to_price(amm_spot_price());
    // }
    // // Rebalance AMM to a desired price
    // function rebalance_AMM_liquidity_to_price(uint256 rebalance_price) public onlyByOwnerOrGovernance {
    //     // Rebalance the ARTHB
    //     _rebalance_AMM_ARTHB();
    //     // Rebalance the ARTH
    //     _rebalance_AMM_ARTH_to_price(rebalance_price);
    // }
    // // Starts a new epoch and rebalances the AMM
    // function startNewEpoch() external onlyByOwnerOrGovernance {
    //     require(!isInEpoch(), 'Already in an existing epoch');
    //     require(!isInCooldown(), 'Bonds are currently settling in the cooldown');
    //     uint256 initial_discount = getInitialDiscount();
    //     // Rebalance the AMM liquidity
    //     rebalance_AMM_liquidity_to_price(PRICE_PRECISION.sub(initial_discount));
    //     // Sanity check in case algorithmicInitialDiscount() messes up somehow or is exploited
    //     require(initial_discount <= failsafe_max_initial_discount, "Initial discount is more than max failsafe");
    //     // Set state variables
    //     epoch_start = block.timestamp;
    //     epoch_end = epoch_start.add(epoch_length);
    //     emit ARTHB_EpochStarted(msg.sender, epoch_start, epoch_end, epoch_length, initial_discount, max_arthb_outstanding);
    // }
    // function getBoundedIn(DirectionChoice choice, uint256 the_floor_price) internal view returns (uint256 bounded_amount) {
    //     uint256 arth_contract_balance = ARTH.balanceOf(address(this));
    //     uint256 arthb_contract_balance = ARTHB.balanceOf(address(this));
    //     if (choice == DirectionChoice.BELOW_TO_FLOOR_ARTH_IN) {
    //         uint256 numerator = sqrt(arth_contract_balance).mul(sqrt(arthb_contract_balance)).mul(sqrt(PRICE_PRECISION));
    //         // The "price" here needs to be inverted
    //         uint256 denominator = sqrt(uint256(PRICE_PRECISION ** 2).div(the_floor_price));
    //         bounded_amount = numerator.div(denominator).sub(arth_contract_balance);
    //     }
    //     else if (choice == DirectionChoice.ABOVE_TO_FLOOR) {
    //         uint256 numerator = sqrt(arth_contract_balance).mul(sqrt(arthb_contract_balance)).mul(sqrt(PRICE_PRECISION));
    //         uint256 denominator = sqrt(the_floor_price);
    //         bounded_amount = numerator.div(denominator).sub(arthb_contract_balance);
    //     }
    // }
    // function toggleIssuing() external {
    //     require(hasRole(ISSUING_PAUSER, msg.sender));
    //     issuingPaused = !issuingPaused;
    // }
    // function toggleBuying() external {
    //     require(hasRole(BUYING_PAUSER, msg.sender));
    //     buyingPaused = !buyingPaused;
    // }
    // function toggleSelling() external {
    //     require(hasRole(SELLING_PAUSER, msg.sender));
    //     sellingPaused = !sellingPaused;
    // }
    // function toggleRedeeming() external {
    //     require(hasRole(REDEEMING_PAUSER, msg.sender));
    //     redeemingPaused = !redeemingPaused;
    // }
    // function toggleDefaultInitialDiscount() external {
    //     require(hasRole(DEFAULT_DISCOUNT_TOGGLER, msg.sender));
    //     useDefaultInitialDiscount = !useDefaultInitialDiscount;
    // }
    // function setTimelock(address new_timelock) external onlyByOwnerOrGovernance {
    //     timelock_address = new_timelock;
    // }
    // function setOwner(address _ownerAddress) external onlyByOwnerOrGovernance {
    //     ownerAddress = _ownerAddress;
    // }
    // function setMaxARTHBOutstanding(uint256 _max_arthb_outstanding) external onlyByOwnerOrGovernance {
    //     max_arthb_outstanding = _max_arthb_outstanding;
    // }
    // function setTargetLiquidity(uint256 _target_liquidity_arthb) external onlyByOwnerOrGovernance {
    //     target_liquidity_arthb = _target_liquidity_arthb;
    // }
    // function setUnissuedARTHB(uint256 _issuable_arthb) external onlyByOwnerOrGovernance {
    //     if (_issuable_arthb > issuable_arthb){
    //         require(((ARTHB.totalSupply()).add(_issuable_arthb)) <= max_arthb_outstanding, "New issue would exceed max_arthb_outstanding");
    //     }
    //     issuable_arthb = _issuable_arthb;
    // }
    // function setFees(uint256 _issue_fee, uint256 _buying_fee, uint256 _selling_fee, uint256 _redemptionFee) external onlyByOwnerOrGovernance {
    //     issue_fee = _issue_fee;
    //     buying_fee = _buying_fee;
    //     selling_fee = _selling_fee;
    //     redemptionFee = _redemptionFee;
    // }
    // function setCooldownPeriod(uint256 _cooldown_period) external onlyByOwnerOrGovernance {
    //     cooldown_period = _cooldown_period;
    // }
    // function setEpochLength(uint256 _epoch_length) external onlyByOwnerOrGovernance {
    //     epoch_length = _epoch_length;
    // }
    // function setDefaultInitialDiscount(uint256 _default_initial_discount, bool _rebalance_AMM) external onlyByOwnerOrGovernance {
    //     default_initial_discount = _default_initial_discount;
    //     if (_rebalance_AMM){
    //         rebalance_AMM_liquidity_to_price(PRICE_PRECISION.sub(getInitialDiscount()));
    //     }
    // }
    // function setFailsafeMaxInitialDiscount(uint256 _failsafe_max_initial_discount) external onlyByOwnerOrGovernance {
    //     failsafe_max_initial_discount = _failsafe_max_initial_discount;
    // }
    // function emergencyRecoverERC20(address tokenAddress, uint256 tokenAmount, address destination_address) external onlyByOwnerOrGovernance {
    //     ERC20(tokenAddress).transfer(destination_address, tokenAmount);
    //     emit Recovered(tokenAddress, destination_address, tokenAmount);
    // }
    // /* ========== PURE FUNCTIONS ========== */
    // // Babylonian method
    // function sqrt(uint y) internal pure returns (uint z) {
    //     if (y > 3) {
    //         z = y;
    //         uint x = y / 2 + 1;
    //         while (x < z) {
    //             z = x;
    //             x = (y / x + x) / 2;
    //         }
    //     } else if (y != 0) {
    //         z = 1;
    //     }
    //     // else z = 0
    // }
    // /* ========== EVENTS ========== */
    // event Recovered(address token, address to, uint256 amount);
    // // Track bond redeeming
    // event ARTHB_Redeemed(address indexed from, uint256 arthb_amount, uint256 arth_out);
    // event ARTHB_EpochStarted(address indexed from, uint256 _epoch_start, uint256 _epoch_end, uint256 _epoch_length, uint256 _initial_discount, uint256 _max_arthb_amount);
}
