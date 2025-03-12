// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import './ARTHB.sol';
import '../Arth/Arth.sol';
import '../ERC20/ERC20.sol';
import '../Math/SafeMath.sol';
import '../Governance/AccessControl.sol';

/**
 *  Original code written by:
 *  - Travis Moore, Jason Huan, Same Kazemian, Sam Sun.
 */
contract ArthBondIssuerWithDeposits is AccessControl {
    // using SafeMath for uint256;
    // /* ========== STATE VARIABLES ========== */
    // enum DirectionChoice { BUY_FROM_AMM, SELL_INTO_AMM }
    // ARTHStablecoin private ARTH;
    // ArthBond private ARTHB;
    // address public ownerAddress;
    // address public timelock_address;
    // uint256 private constant PRICE_PRECISION = 1e6;
    // // Minimum cooldown period before a new epoch, in seconds
    // // Bonds should be redeemed during this time, or they risk being rebalanced with a new epoch
    // uint256 public cooldown_period = 864000; // 10 days
    // // Max ARTHB outstanding
    // uint256 public max_arthb_outstanding = uint256(10000e18);
    // // Set fees, E6
    // uint256 public buying_fee = 1000; // 0.10% initially
    // uint256 public selling_fee = 1000; // 0.10% initially
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
    // bytes32 public constant BUYING_PAUSER = keccak256("BUYING_PAUSER");
    // bytes32 public constant SELLING_PAUSER = keccak256("SELLING_PAUSER");
    // bytes32 public constant REDEEMING_PAUSER = keccak256("REDEEMING_PAUSER");
    // bytes32 public constant DEPOSITING_PAUSER = keccak256("DEPOSITING_PAUSER");
    // bytes32 public constant DEPOSIT_REDEEMING_PAUSER = keccak256("DEPOSIT_REDEEMING_PAUSER");
    // bytes32 public constant DEFAULT_DISCOUNT_TOGGLER = keccak256("DEFAULT_DISCOUNT_TOGGLER");
    // bytes32 public constant BOND_DEPOSIT_UNLOCK_TOGGLER = keccak256("BOND_DEPOSIT_UNLOCK_TOGGLER");
    // bool public buyingPaused = false;
    // bool public sellingPaused = false;
    // bool public redeemingPaused = false;
    // bool public depositingPaused = false;
    // bool public depositRedeemingPaused = false;
    // bool public useDefaultInitialDiscount = false;
    // bool public bond_deposits_unlock_override = false;
    // // BondDeposit variables
    // struct BondDeposit {
    //     bytes32 kek_id;
    //     uint256 amount;
    //     uint256 deposit_timestamp;
    //     uint256 epoch_end_timestamp;
    // }
    // uint256 public deposited_arthb = 0; // Balance of deposited ARTHB, E18
    // mapping(address => BondDeposit[]) public bondDeposits;
    // /* ========== MODIFIERS ========== */
    // modifier onlyByOwnerOrGovernance() {
    //     require(msg.sender == timelock_address || msg.sender == ownerAddress, "You are not the owner or the governance timelock");
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
    // modifier notDepositingPaused() {
    //     require(depositingPaused == false, "Depositing is paused");
    //     _;
    // }
    // modifier notDepositRedeemingPaused() {
    //     require(depositRedeemingPaused == false, "Deposit redeeming is paused");
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
    //     grantRole(BUYING_PAUSER, _ownerAddress);
    //     grantRole(BUYING_PAUSER, _timelock_address);
    //     grantRole(SELLING_PAUSER, _ownerAddress);
    //     grantRole(SELLING_PAUSER, _timelock_address);
    //     grantRole(REDEEMING_PAUSER, _ownerAddress);
    //     grantRole(REDEEMING_PAUSER, _timelock_address);
    //     grantRole(DEPOSITING_PAUSER, _ownerAddress);
    //     grantRole(DEPOSITING_PAUSER, _timelock_address);
    //     grantRole(DEPOSIT_REDEEMING_PAUSER, _ownerAddress);
    //     grantRole(DEPOSIT_REDEEMING_PAUSER, _timelock_address);
    //     grantRole(DEFAULT_DISCOUNT_TOGGLER, _ownerAddress);
    //     grantRole(DEFAULT_DISCOUNT_TOGGLER, _timelock_address);
    //     grantRole(BOND_DEPOSIT_UNLOCK_TOGGLER, _ownerAddress);
    //     grantRole(BOND_DEPOSIT_UNLOCK_TOGGLER, _timelock_address);
    // }
    // /* ========== VIEWS ========== */
    // // Needed for the Arth contract to function
    // function getCollateralGMUBalance() external view returns (uint256) {
    //     return 1; // 1e0
    // }
    // function depositsOf(address account) external view returns (BondDeposit[] memory) {
    //     return bondDeposits[account];
    // }
    // // Checks if the bond is in the cooldown period
    // function isInCooldown() public view returns (bool in_cooldown) {
    //     in_cooldown = ((block.timestamp >= epoch_end) && (block.timestamp < epoch_end.add(cooldown_period)));
    // }
    // // Checks if the bond is in a maturity epoch
    // function isInEpoch() public view returns (bool in_epoch) {
    //     in_epoch = ((block.timestamp >= epoch_start) && (block.timestamp < epoch_end));
    // }
    // // Calculates ARTHB outside the contract
    // function ARTHB_Outside_Contract() public view returns (uint256 arthb_outside_contract) {
    //     arthb_outside_contract = (ARTHB.totalSupply()).sub(ARTHB.balanceOf(address(this)));
    // }
    // // Algorithmically calculated optimal initial discount rate
    // function algorithmicInitialDiscount() public view returns (uint256 initial_discount) {
    //     // TODO: Some fancy algorithm
    //     initial_discount = default_initial_discount;
    // }
    // // AMM price for 1 ARTHB, in ARTH
    // // The contract won't necessarily sell or buy at this price
    // function amm_spot_price() public view returns (uint256 arthb_price) {
    //     arthb_price = getAmountOutNoFee(uint256(1e6), ARTHB.balanceOf(address(this)), ARTH.balanceOf(address(this)));
    // }
    // // ARTHB floor price for 1 ARTHB, in ARTH
    // // Will be used to help prevent someone from doing a huge arb with cheap bonds right before they mature
    // // Also prevents dumping ARTHB into the AMM and depressing the price too much
    // function floor_price() public view returns (uint256 floor_price) {
    //     uint256 time_into_epoch = (block.timestamp).sub(epoch_start);
    //     uint256 initial_discount = getInitialDiscount();
    //     floor_price = (PRICE_PRECISION.sub(initial_discount)).add(initial_discount.mul(time_into_epoch).div(epoch_length));
    // }
    // function initial_price() public view returns (uint256 initial_price) {
    //     initial_price = (PRICE_PRECISION.sub(getInitialDiscount()));
    // }
    // function getInitialDiscount() public view returns (uint256 initial_discount) {
    //     if (useDefaultInitialDiscount){
    //         initial_discount = default_initial_discount;
    //     }
    //     else {
    //         initial_discount = algorithmicInitialDiscount();
    //     }
    // }
    // // Minimum amount of ARTH needed to buy ARTHB
    // // If the AMM price is below the floor, you will need to buy up more to bring it back up
    // // Will be 0 if the AMM price is above the floor price
    // function minimum_arth_for_AMM_buy() public view returns (uint256 minimum_arth_for_buy) {
    //     uint256 the_floor_price = floor_price();
    //     if (amm_spot_price() < the_floor_price){
    //         minimum_arth_for_buy = getBoundedIn(DirectionChoice.BUY_FROM_AMM, the_floor_price);
    //         uint256 fee = minimum_arth_for_buy.mul(buying_fee).div(PRICE_PRECISION);
    //         // Add the fee here instead of subtracting so a tiny bit more ARTH is taken and the price lands
    //         // just above the floor price
    //         minimum_arth_for_buy = minimum_arth_for_buy.add(fee);
    //     }
    //     else {
    //         minimum_arth_for_buy = 0;
    //     }
    // }
    // // Maximum amount of ARTHB you can sell into the AMM at market prices before it hits the floor price and either cuts off
    // // or sells at the floor price, dependingon how sellARTHBintoAMM is called
    // // If the AMM price is above the floor, you may sell ARTHB until doing so would push the price down to the floor
    // // Will be 0 if the AMM price is at or below the floor price
    // function maximum_arthb_AMM_sellable_above_floor() public view returns (uint256 maximum_arthb_for_sell) {
    //     uint256 the_floor_price = floor_price();
    //     if (amm_spot_price() > the_floor_price){
    //         maximum_arthb_for_sell = getBoundedIn(DirectionChoice.SELL_INTO_AMM, the_floor_price);
    //         uint256 fee = maximum_arthb_for_sell.mul(selling_fee).div(PRICE_PRECISION);
    //         maximum_arthb_for_sell = maximum_arthb_for_sell.sub(fee);
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
    // function depositARTHB(uint256 arthb_amount) external notDepositingPaused returns (bytes32 kek_id) {
    //     require(isInEpoch(), 'Not in an epoch');
    //     // Take in the ARTHB from the sender
    //     ARTHB.transferFrom(msg.sender, address(this), arthb_amount);
    //     // Burn ARTHB from the sender
    //     ARTHB.burn(arthb_amount);
    //     // Mark the deposit
    //     deposited_arthb = deposited_arthb.add(arthb_amount);
    //     kek_id = keccak256(abi.encodePacked(msg.sender, block.timestamp, arthb_amount));
    //     bondDeposits[msg.sender].push(BondDeposit(
    //         kek_id,
    //         arthb_amount,
    //         block.timestamp,
    //         epoch_end
    //     ));
    //     emit ARTHB_Deposited(msg.sender, arthb_amount, epoch_end, kek_id);
    // }
    // function buyARTHBfromAMM(uint256 arth_amount, uint256 arthb_out_min, bool should_deposit) external notBuyingPaused returns (uint256 arthb_out, uint256 arthb_fee_amt, bytes32 kek_id) {
    //     require(isInEpoch(), 'Not in an epoch');
    //     require(arth_amount >= minimum_arth_for_AMM_buy(), "Not enough ARTH to satisfy the floor price minimum");
    //     // Get the expected resultant ARTHB price via the AMM
    //     uint256 arthb_out = getAmountOutNoFee(arth_amount, ARTH.balanceOf(address(this)), ARTHB.balanceOf(address(this)));
    //     // Calculate and apply the normal buying fee
    //     arthb_fee_amt = arthb_out.mul(buying_fee).div(PRICE_PRECISION);
    //     // Apply the fee
    //     arthb_out = arthb_out.sub(arthb_fee_amt);
    //     // Check arthb_out_min
    //     require(arthb_out >= arthb_out_min, "[buyARTHBfromAMM arthb_out_min]: Slippage limit reached");
    //     // Take ARTH from the sender
    //     ARTH.transferFrom(msg.sender, address(this), arth_amount);
    //     // The "Forgetful ARTHB Owner Problem"
    //     // Since the ARTHB price resets to the discount after each epoch and cooldown period,
    //     // you can optionally deposit your ARTHB tokens and redeem them any time after that epoch ends
    //     // This is because ARTHB tokens are fungible and have no 'memory' of which epoch they were issued in
    //     // If you forgot to redeem your ARTHB tokens otherwise, you would have to wait until the next cooldown period
    //     // Or take a loss and sell on the open market
    //     if (should_deposit){
    //         require(depositingPaused == false, "Depositing is paused");
    //         // Burn the ARTHB that would have been transfered out to the sender had they not deposited
    //         // This is needed to not mess with the AMM balanceOf(address(this))
    //         ARTHB.burn(arthb_out);
    //         // Mark the deposit
    //         deposited_arthb = deposited_arthb.add(arthb_out);
    //         kek_id = keccak256(abi.encodePacked(msg.sender, block.timestamp, arthb_out));
    //         bondDeposits[msg.sender].push(BondDeposit(
    //             kek_id,
    //             arthb_out,
    //             block.timestamp,
    //             epoch_end
    //         ));
    //         emit ARTHB_Deposited(msg.sender, arthb_out, epoch_end, kek_id);
    //     }
    //     else {
    //         // Give ARTHB to the sender
    //         ARTHB.transfer(msg.sender, arthb_out);
    //     }
    //     // Safety checks (must be done after the transfers in this case)
    //     // Tx will still revert if not true
    //     {
    //         uint256 amm_price = amm_spot_price();
    //         // The AMM will never sell its ARTHB below this
    //         require(amm_price >= floor_price(), "[buyARTHBfromAMM]: floor price reached");
    //     }
    // }
    // function sellARTHBintoAMM(uint256 arthb_amount, uint256 ARTHOutMin, bool sell_excess_at_floor) external notSellingPaused returns (uint256 arthb_at_market_price, uint256 arthb_at_floor_price, uint256 arth_out, uint256 arth_fee_amt) {
    //     require(isInEpoch(), 'Not in an epoch');
    //     // Sell as much as you can at market prices, then the rest at the floor price, unless !sell_excess_at_floor
    //     arthb_at_market_price = 0;
    //     arthb_at_floor_price = 0;
    //     {
    //         uint256 max_above_floor_sellable_arthb = maximum_arthb_AMM_sellable_above_floor();
    //         if(arthb_amount > max_above_floor_sellable_arthb){
    //             if(!sell_excess_at_floor) {
    //                 revert("Sale would push ARTHB below the floor price");
    //             }
    //             else {
    //                 arthb_at_market_price = arthb_amount.sub(max_above_floor_sellable_arthb);
    //                 arthb_at_floor_price = arthb_amount.sub(arthb_at_market_price);
    //             }
    //         }
    //         else {
    //             arthb_at_market_price = arthb_amount;
    //         }
    //     }
    //     // Get the expected amount of ARTH via the AMM from the market-priced portion
    //     arth_out = getAmountOutNoFee(arthb_at_market_price, ARTHB.balanceOf(address(this)), ARTH.balanceOf(address(this)));
    //     // Add in the ARTH from the floor-priced portion
    //     uint256 the_floor_price = floor_price();
    //     arth_out = arth_out.add(arthb_at_floor_price.mul(the_floor_price).div(PRICE_PRECISION));
    //     // Apply the normal selling fee
    //     arth_fee_amt = arth_out.mul(selling_fee).div(PRICE_PRECISION);
    //     arth_out = arth_out.sub(arth_fee_amt);
    //     // Check ARTHOutMin
    //     require(arth_out >= ARTHOutMin, "[sellARTHBintoAMM ARTHOutMin]: Slippage limit reached");
    //     // Take ARTHB from the sender
    //     ARTHB.transferFrom(msg.sender, address(this), arthb_amount);
    //     // Give ARTH to sender
    //     ARTH.transfer(msg.sender, arth_out);
    //     // Safety checks (must be done after the transfers in this case)
    //     // Tx will still revert if not true
    //     {
    //         uint256 amm_price = amm_spot_price();
    //         // The AMM will never buy the ARTHB back above 1
    //         require(amm_price <= PRICE_PRECISION, "[sellARTHBintoAMM]: price is above 1");
    //         // The AMM will never buy the ARTHB back below this
    //         require(amm_price >= the_floor_price, "[sellARTHBintoAMM]: floor price reached");
    //     }
    // }
    // function redeemARTHB(uint256 arthb_amount) external notRedeemingPaused returns (uint256 arth_out, uint256 arth_fee) {
    //     require(isInCooldown(), 'Not in the cooldown period');
    //     // Take ARTHB from the sender
    //     ARTHB.transferFrom(msg.sender, address(this), arthb_amount);
    //     // Give 1 ARTH per 1 ARTHB, minus the redemption fee
    //     arth_fee = arthb_amount.mul(redemptionFee).div(PRICE_PRECISION);
    //     arth_out = arthb_amount.sub(arth_fee);
    //     ARTH.poolMint(msg.sender, arth_out);
    //     emit ARTHB_Redeemed(msg.sender, arthb_amount, arth_out);
    // }
    // function redeemDepositedARTHB(bytes32 kek_id) external notDepositRedeemingPaused returns (uint256 arth_out, uint256 arth_fee) {
    //     BondDeposit memory thisDeposit;
    //     thisDeposit.amount = 0;
    //     uint theIndex;
    //     for (uint i = 0; i < bondDeposits[msg.sender].length; i++){
    //         if (kek_id == bondDeposits[msg.sender][i].kek_id){
    //             thisDeposit = bondDeposits[msg.sender][i];
    //             theIndex = i;
    //             break;
    //         }
    //     }
    //     require(thisDeposit.kek_id == kek_id, "Deposit not found");
    //     require((block.timestamp >= thisDeposit.epoch_end_timestamp  == true) || bond_deposits_unlock_override, "Deposit is still maturing!");
    //     uint256 arthb_amount = thisDeposit.amount;
    //     // Remove the bond deposit from the array
    //     delete bondDeposits[msg.sender][theIndex];
    //     // Decrease the deposited bonds tracker
    //     deposited_arthb = deposited_arthb.sub(arthb_amount);
    //     // Give 1 ARTH per 1 ARTHB, minus the redemption fee
    //     arth_fee = arthb_amount.mul(redemptionFee).div(PRICE_PRECISION);
    //     uint256 arth_out = arthb_amount.sub(arth_fee);
    //     ARTH.poolMint(msg.sender, arth_out);
    //     emit ARTHB_Deposit_Redeemed(msg.sender, arthb_amount, arth_out, epoch_end, kek_id);
    // }
    // /* ========== RESTRICTED INTERNAL FUNCTIONS ========== */
    // // Burns as much ARTHB as possible that the contract owns
    // // Some could still remain outside of the contract
    // function _burnExcessARTHB() internal returns (uint256 arthb_total_supply, uint256 arthb_adjusted_total_supply, uint256 arthb_inside_contract, uint256 arthb_outside_contract, uint256 burn_amount) {
    //     // Get the balances
    //     arthb_total_supply = ARTHB.totalSupply();
    //     arthb_adjusted_total_supply = arthb_total_supply.add(deposited_arthb); // Don't forget to account for deposited ARTHB
    //     arthb_inside_contract = ARTHB.balanceOf(address(this));
    //     arthb_outside_contract = arthb_total_supply.sub(arthb_inside_contract);
    //     // Only need to burn if there is an excess
    //     if (arthb_adjusted_total_supply > max_arthb_outstanding){
    //         uint256 total_excess_arthb = arthb_adjusted_total_supply.sub(max_arthb_outstanding);
    //         // If the contract has some excess ARTHB, try to burn it
    //         if(arthb_inside_contract >= total_excess_arthb){
    //             // Burn the entire excess amount
    //             burn_amount = total_excess_arthb;
    //         }
    //         else {
    //             // Burn as much as you can
    //             burn_amount = arthb_inside_contract;
    //         }
    //         // Do the burning
    //         ARTHB.burn(burn_amount);
    //         // Fetch the new balances
    //         arthb_total_supply = ARTHB.totalSupply();
    //         arthb_adjusted_total_supply = arthb_total_supply.add(deposited_arthb);
    //         arthb_inside_contract = ARTHB.balanceOf(address(this));
    //         arthb_outside_contract = arthb_total_supply.sub(arthb_inside_contract);
    //     }
    // }
    // /* ========== RESTRICTED EXTERNAL FUNCTIONS ========== */
    // // Allows for burning new ARTHB in the middle of an epoch
    // // The contraction must occur at the current AMM price, so both sides (ARTH and ARTHB) need to be burned
    // function contract_AMM_liquidity(uint256 arthb_contraction_amount) external onlyByOwnerOrGovernance {
    //     require(isInEpoch(), 'Not in an epoch');
    //     // Get the AMM spot price
    //     uint256 arthb_spot_price = amm_spot_price();
    //     // Update max_arthb_outstanding
    //     max_arthb_outstanding = max_arthb_outstanding.sub(arthb_contraction_amount);
    //     // Burn the required ARTH
    //     ARTH.burn(arthb_contraction_amount.mul(arthb_spot_price).div(PRICE_PRECISION));
    //     // Burn the required ARTHB
    //     ARTHB.burn(arthb_contraction_amount);
    // }
    // // Allows for minting new ARTHB in the middle of an epoch
    // // The expansion must occur at the current AMM price, so both sides (ARTH and ARTHB) need to be minted
    // function expand_AMM_liquidity(uint256 arthb_expansion_amount) external onlyByOwnerOrGovernance {
    //     require(isInEpoch(), 'Not in an epoch');
    //     // Get the AMM spot price
    //     uint256 arthb_spot_price = amm_spot_price();
    //     // Update max_arthb_outstanding
    //     max_arthb_outstanding = max_arthb_outstanding.add(arthb_expansion_amount);
    //     // Mint the required ARTH
    //     ARTH.poolMint(address(this), arthb_expansion_amount.mul(arthb_spot_price).div(PRICE_PRECISION));
    //     // Mint the required ARTHB
    //     ARTHB.issuer_mint(address(this), arthb_expansion_amount);
    // }
    // // Starts a new epoch and rebalances the AMM
    // function startNewEpoch() external onlyByOwnerOrGovernance {
    //     require(!isInEpoch(), 'Already in an existing epoch');
    //     require(!isInCooldown(), 'Bonds are currently settling in the cooldown');
    //     uint256 initial_discount = getInitialDiscount();
    //     // Sanity check in case algorithmicInitialDiscount() messes up somehow or is exploited
    //     require(initial_discount <= failsafe_max_initial_discount, "Initial discount is more than max failsafe");
    //     // There still will be probably still be some bonds floating around outside, so we need to account for those
    //     // They may also accumulate over time
    //     {
    //         // Burn any excess ARTHB
    //         (uint256 arthb_total_supply, uint256 arthb_adjusted_total_supply, uint256 arthb_inside_contract, uint256 arthb_outside_contract, ) = _burnExcessARTHB();
    //         // Fail if there is still too much ARTHB
    //         require(arthb_adjusted_total_supply <= max_arthb_outstanding, "Still too much ARTHB outstanding" );
    //         // Mint ARTHB up to max_arthb_outstanding
    //         uint256 arthb_needed = max_arthb_outstanding.sub(arthb_outside_contract).sub(arthb_inside_contract).sub(deposited_arthb);
    //         ARTHB.issuer_mint(address(this), arthb_needed);
    //     }
    //     // Mint or burn ARTH to get to the initial_discount
    //     {
    //         uint256 desired_arth_amount = max_arthb_outstanding.mul(PRICE_PRECISION.sub(initial_discount)).div(PRICE_PRECISION);
    //         uint256 arth_inside_contract = ARTH.balanceOf(address(this));
    //         if (desired_arth_amount > arth_inside_contract){
    //             // Mint the deficiency
    //             ARTH.poolMint(address(this), desired_arth_amount.sub(arth_inside_contract));
    //         }
    //         else if (desired_arth_amount < arth_inside_contract){
    //             // Burn the excess
    //             ARTH.burn(arth_inside_contract.sub(desired_arth_amount));
    //         }
    //         else { /* Do nothing */ }
    //     }
    //     // Set state variables
    //     epoch_start = block.timestamp;
    //     epoch_end = epoch_start.add(epoch_length);
    //     emit ARTHB_EpochStarted(msg.sender, epoch_start, epoch_end, epoch_length, initial_discount, max_arthb_outstanding);
    // }
    // // This method CAN have some error
    // function getBoundedIn(DirectionChoice choice, uint256 the_floor_price) internal view returns (uint256 bounded_amount) {
    //     uint256 arth_contract_balance = ARTH.balanceOf(address(this));
    //     uint256 arthb_contract_balance = ARTHB.balanceOf(address(this));
    //     if (choice == DirectionChoice.BUY_FROM_AMM) {
    //         uint256 numerator = sqrt(arth_contract_balance).mul(sqrt(arthb_contract_balance)).mul(sqrt(PRICE_PRECISION));
    //         // The "price" here needs to be inverted
    //         uint256 denominator = sqrt(uint256(PRICE_PRECISION ** 2).div(the_floor_price));
    //         bounded_amount = numerator.div(denominator).sub(arth_contract_balance);
    //     }
    //     else if (choice == DirectionChoice.SELL_INTO_AMM) {
    //         uint256 numerator = sqrt(arth_contract_balance).mul(sqrt(arthb_contract_balance)).mul(sqrt(PRICE_PRECISION));
    //         uint256 denominator = sqrt(the_floor_price);
    //         bounded_amount = numerator.div(denominator).sub(arthb_contract_balance);
    //     }
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
    // function toggleDepositing() external {
    //     require(hasRole(DEPOSITING_PAUSER, msg.sender));
    //     depositingPaused = !depositingPaused;
    // }
    // function toggleDepositRedeeming() external {
    //     require(hasRole(DEPOSIT_REDEEMING_PAUSER, msg.sender));
    //     depositRedeemingPaused = !depositRedeemingPaused;
    // }
    // function toggleUniversalDepositUnlock() external {
    //     require(hasRole(BOND_DEPOSIT_UNLOCK_TOGGLER, msg.sender));
    //     bond_deposits_unlock_override = !bond_deposits_unlock_override;
    // }
    // function setTimelock(address new_timelock) external onlyByOwnerOrGovernance {
    //     timelock_address = new_timelock;
    // }
    // function toggleDefaultInitialDiscount() external {
    //     require(hasRole(DEFAULT_DISCOUNT_TOGGLER, msg.sender));
    //     useDefaultInitialDiscount = !useDefaultInitialDiscount;
    // }
    // function setOwner(address _ownerAddress) external onlyByOwnerOrGovernance {
    //     ownerAddress = _ownerAddress;
    // }
    // function setMaxARTHBOutstanding(uint256 _max_arthb_outstanding) external onlyByOwnerOrGovernance {
    //     max_arthb_outstanding = _max_arthb_outstanding;
    // }
    // function setFees(uint256 _buying_fee, uint256 _selling_fee, uint256 _redemptionFee) external onlyByOwnerOrGovernance {
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
    // function setDefaultInitialDiscount(uint256 _default_initial_discount) external onlyByOwnerOrGovernance {
    //     default_initial_discount = _default_initial_discount;
    // }
    // function setFailsafeMaxInitialDiscount(uint256 _failsafe_max_initial_discount) external onlyByOwnerOrGovernance {
    //     failsafe_max_initial_discount = _failsafe_max_initial_discount;
    // }
    // function emergencyRecoverERC20(address tokenAddress, uint256 tokenAmount, address destination_address) external onlyByOwnerOrGovernance {
    //     ERC20(tokenAddress).transfer(destination_address, tokenAmount);
    //     emit Recovered(tokenAddress, destination_address, tokenAmount);
    // }
    // /* ========== PURE FUNCTIONS ========== */
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
    // event ARTHB_Deposited(address indexed from, uint256 arthb_amount, uint256 epoch_end, bytes32 kek_id);
    // event ARTHB_Deposit_Redeemed(address indexed from, uint256 arthb_amount, uint256 arth_out, uint256 epoch_end, bytes32 kek_id);
    // event ARTHB_Redeemed(address indexed from, uint256 arthb_amount, uint256 arth_out);
    // event ARTHB_EpochStarted(address indexed from, uint256 _epoch_start, uint256 _epoch_end, uint256 _epoch_length, uint256 _initial_discount, uint256 _max_arthb_amount);
}
