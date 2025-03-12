// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '../../uniswap/TransferHelper.sol';
import "../../gr/Gr.sol";
import "../ISynth.sol";
import "../../erc20/ERC20.sol";
import "../../oracle/interface/IUniswapPairOracle.sol";
import "../../oracle/interface/IChainlinkOracle.sol";
import "./PoolLibrary.sol";

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

contract Pool is Initializable, ContextUpgradeable, AccessControlUpgradeable, OwnableUpgradeable  {
    using SafeMathUpgradeable for uint256;

    /* ========== STATE VARIABLES ========== */

    ERC20 private collateral_token;
    address public collateral_address;

    address private synth_contract_address;
    address private gr_contract_address;
    address private timelock_address;
    GrShares private Gr;
    ISynth private Synth;

    IChainlinkOracle private collat_anchor_pricer;
    address public collat_anchor_oracle_address;
    uint8   private callat_anchor_pricer_decimals;

    uint256 public minting_fee;
    uint256 public redemption_fee;
    uint256 public buyback_fee;
    uint256 public recollat_fee;

    mapping (address => uint256) public redeemGrBalances;
    mapping (address => uint256) public redeemCollateralBalances;
    mapping (address => uint256) public mintSynthBalances;
    uint256 public unclaimedPoolCollateral;
    uint256 public unclaimedPoolGr;
    uint256 public unclaimedPoolSynth;
    mapping (address => uint256) public lastRedeemed;
    mapping (address => uint256) public lastMint;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;
    uint256 private constant COLLATERAL_RATIO_PRECISION = 1e6;
    uint256 private constant COLLATERAL_RATIO_MAX = 1e6;

    // Number of decimals needed to get to 18
    uint256 private missing_decimals;

    // Pool_ceiling is the total units of collateral that a pool contract can hold
    uint256 public pool_ceiling;

    // Stores price of the collateral, if price is paused
    uint256 public pausedPrice;

    // Bonus rate on Gr minted during recollateralizeSynth(); 6 decimals of precision, set to 1% on genesis
    uint256 public bonus_rate;

    // Number of blocks to wait before being able to collectRedemption()
    uint256 public redemption_delay;

    uint256 public redeem_price_threshold; // $0.99
    uint256 public mint_price_threshold; // $1.01

    // AccessControl Roles
    bytes32 private constant MINT_PAUSER = keccak256("MINT_PAUSER");
    bytes32 private constant REDEEM_PAUSER = keccak256("REDEEM_PAUSER");
    bytes32 private constant BUYBACK_PAUSER = keccak256("BUYBACK_PAUSER");
    bytes32 private constant RECOLLATERALIZE_PAUSER = keccak256("RECOLLATERALIZE_PAUSER");
    bytes32 private constant COLLATERAL_PRICE_PAUSER = keccak256("COLLATERAL_PRICE_PAUSER");

    // AccessControl state variables
    bool public mintPaused;
    bool public redeemPaused;
    bool public recollateralizePaused;
    bool public buyBackPaused;
    bool public collateralPricePaused;
    
    bool public priceVerify;

    address public devAddr;

    /* ========== MODIFIERS ========== */

    modifier onlyByOwnGov() {
        require(msg.sender == timelock_address || msg.sender == owner(), "Not owner or timelock");
        _;
    }

    modifier notRedeemPaused() {
        require(redeemPaused == false, "Redeeming is paused");
        _;
    }

    modifier notMintPaused() {
        require(mintPaused == false, "Minting is paused");
        _;
    }

    modifier canRedeem() {
        // Prevent unneccessary redemptions that could adversely affect the GR price
        require(Synth.synth_price() <= redeem_price_threshold || !priceVerify, "Synth price too high");
        _;
    }

    modifier canMint() {
        // Prevent unneccessary mints
        require(Synth.synth_price() >= mint_price_threshold || !priceVerify, "Synth price too low");
        _;
    }


    /* ========== initialize ========== */

    function initialize(
        address _synth_contract_address,
        address _gr_contract_address,
        address _collateral_address,
        address _timelock_address,
        uint256 _pool_ceiling
    ) public initializer {
        require(
            (_synth_contract_address != address(0))
            && (_gr_contract_address != address(0))
            && (_collateral_address != address(0))
            && (_timelock_address != address(0))
        , "Zero address detected");

        __Context_init();
        __Ownable_init();
        __AccessControl_init();

        Synth = ISynth(_synth_contract_address);
        Gr = GrShares(_gr_contract_address);
        synth_contract_address = _synth_contract_address;
        gr_contract_address = _gr_contract_address;
        collateral_address = _collateral_address;
        timelock_address = _timelock_address;
        collateral_token = ERC20(_collateral_address);
        pool_ceiling = _pool_ceiling;
        missing_decimals = uint(18).sub(collateral_token.decimals());

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        grantRole(MINT_PAUSER, timelock_address);
        grantRole(REDEEM_PAUSER, timelock_address);
        grantRole(RECOLLATERALIZE_PAUSER, timelock_address);
        grantRole(BUYBACK_PAUSER, timelock_address);
        grantRole(COLLATERAL_PRICE_PAUSER, timelock_address);

        pausedPrice = 0;
        bonus_rate = 10000;
        redemption_delay = 1;
        redeem_price_threshold = 995000;
        mint_price_threshold = 1005000;
        mintPaused = false;
        redeemPaused = false;
        recollateralizePaused = false;
        buyBackPaused = false;
        collateralPricePaused = false;
        priceVerify = false;
    }

    /* ========== VIEWS ========== */

    // Returns the value of excess collateral held in this Synth pool, compared to what is needed to maintain the global collateral ratio
    function availableExcessCollatDV() public view returns (uint256) {
        uint256 total_supply = Synth.totalSupply();
        uint256 global_collateral_ratio = Synth.global_collateral_ratio();
        uint256 global_collat_value = Synth.globalCollateralValue();

        if (global_collateral_ratio > COLLATERAL_RATIO_PRECISION) global_collateral_ratio = COLLATERAL_RATIO_PRECISION; // Handles an overcollateralized contract with CR > 1
        uint256 required_collat_synth_value_d18 = (total_supply.mul(global_collateral_ratio)).div(COLLATERAL_RATIO_PRECISION); // Calculates collateral needed to back each 1 Synth with $1 of collateral at current collat ratio
        if (global_collat_value > required_collat_synth_value_d18) return global_collat_value.sub(required_collat_synth_value_d18);
        else return 0;
    }
    
    
    // Returns the value of excess Gr held in this Synth pool, compared to what is needed to maintain the global collateral ratio
    function availableExcessGrDV() public view returns (uint256) {
        
        uint256 synth_total_supply = Synth.totalSupply();
        uint256 global_collateral_ratio = Synth.global_collateral_ratio();
        uint256 global_collat_value = Synth.globalCollateralValue();
        
        uint256 effective_collateral_ratio = global_collat_value.mul(1e6).div(synth_total_supply); //returns it in 1e6
        if (global_collateral_ratio > effective_collateral_ratio){
            return (global_collateral_ratio.mul(synth_total_supply).sub(synth_total_supply.mul(effective_collateral_ratio))).div(1e6);
        }
        return 0;
    }
    

    /* ========== PUBLIC FUNCTIONS ========== */

    // Returns Anchor value of collateral held in this Synth pool
    function collatAnchorBalance() public view returns (uint256) {
        return (collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral)).mul(getCollateralPrice()).div(PRICE_PRECISION);
    }

    // Returns the price of the pool collateral in Anchor
    // 1 Collateral = X Anchor
    function getCollateralPrice() public view returns (uint256) {
        if(collateralPricePaused == true){
            return pausedPrice;
        } else {
            return uint256(collat_anchor_pricer.getLatestPrice()).mul(PRICE_PRECISION).div(uint256(10) ** callat_anchor_pricer_decimals);
        }
    }

    function setChainlinkCollatAnchorOracle(address _collat_anchor_consumer_address) public onlyByOwnGov {
        require(_collat_anchor_consumer_address != address(0), "Zero address detected");

        collat_anchor_oracle_address = _collat_anchor_consumer_address;
        collat_anchor_pricer = IChainlinkOracle(collat_anchor_oracle_address);
        callat_anchor_pricer_decimals = collat_anchor_pricer.getDecimals();

        emit BNBCollatOracleSet(_collat_anchor_consumer_address);
    }

    // We separate out the 1t1, fractional and algorithmic minting functions for gas efficiency
    function mint1t1Synth(uint256 collateral_amount, uint256 synth_out_min) external notMintPaused canMint{
        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);

        require(Synth.global_collateral_ratio() >= COLLATERAL_RATIO_MAX, "Collateral ratio must be >= 1");
        require((collateral_token.balanceOf(address(this))).sub(unclaimedPoolCollateral).add(collateral_amount) <= pool_ceiling, "[Pool's Closed]: Ceiling reached");

        (uint256 synth_amount_d18) = PoolLibrary.calcMint1t1Synth(
            getCollateralPrice(),
            collateral_amount_d18
        ); //1 Synth for each $1 worth of collateral

        uint256 fee = synth_amount_d18.mul(minting_fee).div(1e6); //remove precision at the end
        synth_amount_d18 = (synth_amount_d18.mul(uint(1e6).sub(minting_fee))).div(1e6); //remove precision at the end
        require(synth_out_min <= synth_amount_d18, "Slippage limit reached");

        TransferHelper.safeTransferFrom(address(collateral_token), msg.sender, address(this), collateral_amount);

        mintSynthBalances[msg.sender] = mintSynthBalances[msg.sender].add(synth_amount_d18);
        mintSynthBalances[devAddr] = mintSynthBalances[devAddr].add(fee);
        unclaimedPoolSynth = unclaimedPoolSynth.add(synth_amount_d18).add(fee);
        lastMint[msg.sender] = block.number;

        Synth.pool_mint(address(this), synth_amount_d18.add(fee));
    }

    // 0% collateral-backed
    function mintAlgorithmicSynth(uint256 gr_amount_d18, uint256 synth_out_min) external notMintPaused canMint{
        uint256 gr_price = Synth.gr_price();
        require(Synth.global_collateral_ratio() == 0, "Collateral ratio must be 0");

        (uint256 synth_amount_d18) = PoolLibrary.calcMintAlgorithmicSynth(
            gr_price, // 1 Gr = X Synth
            gr_amount_d18
        );

        uint256 fee = synth_amount_d18.mul(minting_fee).div(1e6);
        synth_amount_d18 = (synth_amount_d18.mul(uint(1e6).sub(minting_fee))).div(1e6);
        require(synth_out_min <= synth_amount_d18, "Slippage limit reached");

        Gr.pool_burn_from(msg.sender, gr_amount_d18);

        mintSynthBalances[msg.sender] = mintSynthBalances[msg.sender].add(synth_amount_d18);
        mintSynthBalances[devAddr] = mintSynthBalances[devAddr].add(fee);
        unclaimedPoolSynth = unclaimedPoolSynth.add(synth_amount_d18).add(fee);
        lastMint[msg.sender] = block.number;

        Synth.pool_mint(address(this), synth_amount_d18.add(fee));
    }

    // Will fail if fully collateralized or fully algorithmic
    // > 0% and < 100% collateral-backed
    function mintFractionalSynth(uint256 collateral_amount, uint256 gr_amount, uint256 synth_out_min) external notMintPaused canMint{
        uint256 gr_price = Synth.gr_price();
        uint256 global_collateral_ratio = Synth.global_collateral_ratio();

        require(global_collateral_ratio < COLLATERAL_RATIO_MAX && global_collateral_ratio > 0, "Collateral ratio needs to be between .000001 and .999999");
        require(collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral).add(collateral_amount) <= pool_ceiling, "Pool ceiling reached, no more Synth can be minted with this collateral");

        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);
        PoolLibrary.MintFF_Params memory input_params = PoolLibrary.MintFF_Params(
            gr_price,
            getCollateralPrice(),
            gr_amount,
            collateral_amount_d18,
            global_collateral_ratio
        );

        (uint256 mint_amount, uint256 gr_needed) = PoolLibrary.calcMintFractionalSynth(input_params);

        uint256 fee = mint_amount.mul(minting_fee).div(1e6);
        mint_amount = (mint_amount.mul(uint(1e6).sub(minting_fee))).div(1e6);
        require(synth_out_min <= mint_amount, "Slippage limit reached");
        require(gr_needed <= gr_amount, "Not enough Gr inputted");

        Gr.pool_burn_from(msg.sender, gr_needed);
        TransferHelper.safeTransferFrom(address(collateral_token), msg.sender, address(this), collateral_amount);

        mintSynthBalances[msg.sender] = mintSynthBalances[msg.sender].add(mint_amount);
        mintSynthBalances[devAddr] = mintSynthBalances[devAddr].add(fee);
        unclaimedPoolSynth = unclaimedPoolSynth.add(mint_amount).add(fee);
        lastMint[msg.sender] = block.number;

        Synth.pool_mint(address(this), mint_amount.add(fee));
    }

    // Redeem collateral. 100% collateral-backed
    function redeem1t1Synth(uint256 synth_amount, uint256 COLLATERAL_out_min) external notRedeemPaused canRedeem{
        require(Synth.global_collateral_ratio() == COLLATERAL_RATIO_MAX, "Collateral ratio must be == 1");

        // Need to adjust for decimals of collateral
        uint256 synth_amount_precision = synth_amount.div(10 ** missing_decimals);
        (uint256 collateral_needed) = PoolLibrary.calcRedeem1t1Synth(
            getCollateralPrice(),
            synth_amount_precision
        );

        uint256 fee = collateral_needed.mul(redemption_fee).div(1e6);
        collateral_needed = (collateral_needed.mul(uint(1e6).sub(redemption_fee))).div(1e6);
        require(collateral_needed.add(fee) <= collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral), "Not enough collateral in pool");
        require(COLLATERAL_out_min <= collateral_needed, "Slippage limit reached");

        redeemCollateralBalances[msg.sender] = redeemCollateralBalances[msg.sender].add(collateral_needed);
        redeemCollateralBalances[devAddr] = redeemCollateralBalances[devAddr].add(fee);

        unclaimedPoolCollateral = unclaimedPoolCollateral.add(collateral_needed).add(fee);
        lastRedeemed[msg.sender] = block.number;

        // Move all external functions to the end
        Synth.pool_burn_from(msg.sender, synth_amount);
    }

    // Will fail if fully collateralized or algorithmic
    // Redeem Synth for collateral and Gr. > 0% and < 100% collateral-backed
    function redeemFractionalSynth(uint256 synth_amount, uint256 Gr_out_min, uint256 COLLATERAL_out_min) external notRedeemPaused canRedeem {
        uint256 gr_price = Synth.gr_price();
        uint256 global_collateral_ratio = Synth.global_collateral_ratio();

        require(global_collateral_ratio < COLLATERAL_RATIO_MAX && global_collateral_ratio > 0, "Collateral ratio needs to be between .000001 and .999999");
        uint256 col_price_anchor = getCollateralPrice();

        uint256 fee = synth_amount.mul(redemption_fee).div(PRICE_PRECISION);
        uint256 synth_amount_post_fee = (synth_amount.mul(uint(1e6).sub(redemption_fee))).div(PRICE_PRECISION);

        uint256 gr_synth_value_d18 = synth_amount_post_fee.sub(synth_amount_post_fee.mul(global_collateral_ratio).div(PRICE_PRECISION));
        uint256 gr_amount = gr_synth_value_d18.mul(PRICE_PRECISION).div(gr_price);

        // Need to adjust for decimals of collateral
        uint256 synth_amount_precision = synth_amount_post_fee.div(10 ** missing_decimals);
        uint256 collateral_synth_value = synth_amount_precision.mul(global_collateral_ratio).div(PRICE_PRECISION);
        uint256 collateral_amount = collateral_synth_value.mul(PRICE_PRECISION).div(col_price_anchor);

        require(collateral_amount <= collateral_token.balanceOf(address(this)).sub(unclaimedPoolCollateral), "Not enough collateral in pool");
        require(COLLATERAL_out_min <= collateral_amount, "Slippage limit reached [collateral]");
        require(Gr_out_min <= gr_amount, "Slippage limit reached [Gr]");

        redeemCollateralBalances[msg.sender] = redeemCollateralBalances[msg.sender].add(collateral_amount);
        unclaimedPoolCollateral = unclaimedPoolCollateral.add(collateral_amount);

        redeemGrBalances[msg.sender] = redeemGrBalances[msg.sender].add(gr_amount);
        unclaimedPoolGr = unclaimedPoolGr.add(gr_amount);

        lastRedeemed[msg.sender] = block.number;

        // Move all external functions to the end
        Synth.pool_mint(devAddr, fee);
        Synth.pool_burn_from(msg.sender, synth_amount);
        Gr.pool_mint(address(this), gr_amount);
    }

    // Redeem Synth for Gr. 0% collateral-backed
    function redeemAlgorithmicSynth(uint256 synth_amount, uint256 Gr_out_min) external notRedeemPaused canRedeem {
        uint256 gr_price = Synth.gr_price();
        uint256 global_collateral_ratio = Synth.global_collateral_ratio();

        require(global_collateral_ratio == 0, "Collateral ratio must be 0");
        uint256 gr_synth_value_d18 = synth_amount;

        // fee
        uint256 fee_d18 =  gr_synth_value_d18.mul(redemption_fee).div(PRICE_PRECISION);
        uint256 fee = fee_d18.mul(PRICE_PRECISION).div(gr_price);

        gr_synth_value_d18 = (gr_synth_value_d18.mul(uint(1e6).sub(redemption_fee))).div(PRICE_PRECISION); //apply fees
        uint256 gr_amount = gr_synth_value_d18.mul(PRICE_PRECISION).div(gr_price);

        redeemGrBalances[msg.sender] = redeemGrBalances[msg.sender].add(gr_amount);
        redeemGrBalances[devAddr] = redeemGrBalances[devAddr].add(fee);
        unclaimedPoolGr = unclaimedPoolGr.add(gr_amount).add(fee);

        lastRedeemed[msg.sender] = block.number;

        require(Gr_out_min <= gr_amount, "Slippage limit reached");
        // Move all external functions to the end
        Synth.pool_burn_from(msg.sender, synth_amount);
        Gr.pool_mint(address(this), gr_amount);
    }

    // After a redemption happens, transfer the newly minted Gr and owed collateral from this pool
    // contract to the user. Redemption is split into two functions to prevent flash loans from being able
    // to take out Synth/collateral from the system, use an AMM to trade the new price, and then mint back into the system.
    function collectRedemption() external {
        require((lastRedeemed[msg.sender].add(redemption_delay)) <= block.number, "Must wait for redemption_delay blocks before collecting redemption");
        require((lastMint[msg.sender].add(redemption_delay)) <= block.number, "Must wait for redemption_delay blocks before collecting redemption");

        bool sendGr = false;
        bool sendCollateral = false;
        bool sendAnchor = false;
        uint GrAmount = 0;
        uint CollateralAmount = 0;
        uint anchorAmount = 0;

        // Use Checks-Effects-Interactions pattern
        if(redeemGrBalances[msg.sender] > 0){
            GrAmount = redeemGrBalances[msg.sender];
            redeemGrBalances[msg.sender] = 0;
            unclaimedPoolGr = unclaimedPoolGr.sub(GrAmount);

            sendGr = true;
        }

        if(redeemCollateralBalances[msg.sender] > 0){
            CollateralAmount = redeemCollateralBalances[msg.sender];
            redeemCollateralBalances[msg.sender] = 0;
            unclaimedPoolCollateral = unclaimedPoolCollateral.sub(CollateralAmount);

            sendCollateral = true;
        }

        if(mintSynthBalances[msg.sender] > 0){
            anchorAmount = mintSynthBalances[msg.sender];
            mintSynthBalances[msg.sender] = 0;
            unclaimedPoolSynth = unclaimedPoolSynth.sub(anchorAmount);

            sendAnchor = true;
        }

        if(sendGr){
            TransferHelper.safeTransfer(address(Gr), msg.sender, GrAmount);
        }
        if(sendCollateral){
            TransferHelper.safeTransfer(address(collateral_token), msg.sender, CollateralAmount);
        }
        if(sendAnchor){
            TransferHelper.safeTransfer(address(Synth), msg.sender, anchorAmount);
        }
    }


    // When the protocol is recollateralizing, we need to give a discount of Gr to hit the new CR target
    // Thus, if the target collateral ratio is higher than the actual value of collateral, minters get Gr for adding collateral
    // This function simply rewards anyone that sends collateral to a pool with the same amount of Gr + the bonus rate
    // Anyone can call this function to recollateralize the protocol and take the extra Gr value from the bonus rate as an arb opportunity
    function recollateralizeSynth(uint256 collateral_amount, uint256 Gr_out_min) external {
        require(recollateralizePaused == false, "Recollateralize is paused");
        uint256 collateral_amount_d18 = collateral_amount * (10 ** missing_decimals);
        uint256 gr_price = Synth.gr_price();
        uint256 synth_total_supply = Synth.totalSupply();
        uint256 global_collateral_ratio = Synth.global_collateral_ratio();
        uint256 global_collat_value = Synth.globalCollateralValue();

        (uint256 collateral_units, uint256 amount_to_recollat) = PoolLibrary.calcRecollateralizeSynthInner(
            collateral_amount_d18,
            getCollateralPrice(),
            global_collat_value,
            synth_total_supply,
            global_collateral_ratio
        );

        uint256 collateral_units_precision = collateral_units.div(10 ** missing_decimals);

        uint256 gr_fee = amount_to_recollat.mul(recollat_fee).div(gr_price);
        uint256 gr_paid_back = amount_to_recollat.mul(uint(1e6).add(bonus_rate).sub(recollat_fee)).div(gr_price);

        require(Gr_out_min <= gr_paid_back, "Slippage limit reached");
        TransferHelper.safeTransferFrom(address(collateral_token), msg.sender, address(this), collateral_units_precision);
        Gr.pool_mint(msg.sender, gr_paid_back);
        Gr.pool_mint(devAddr, gr_fee);
    }

    // Function can be called by an Gr holder to have the protocol buy back Gr with excess collateral value from a desired collateral pool
    // This can also happen if the collateral ratio > 1
    function buyBackGr(uint256 Gr_amount, uint256 COLLATERAL_out_min) external {
        require(buyBackPaused == false, "Buyback is paused");
        uint256 gr_price = Synth.gr_price();

        PoolLibrary.BuybackGr_Params memory input_params = PoolLibrary.BuybackGr_Params(
            availableExcessCollatDV(),
            gr_price,
            getCollateralPrice(),
            Gr_amount
        );

        uint256 collateral_amount = PoolLibrary.calcBuyBackGr(input_params);

        (uint256 fee_d18) = collateral_amount.mul(buyback_fee).div(1e6);
        uint256 fee = fee_d18.div(10 ** missing_decimals);

        (uint256 collateral_equivalent_d18) = collateral_amount.mul(uint(1e6).sub(buyback_fee)).div(1e6);
        uint256 collateral_precision = collateral_equivalent_d18.div(10 ** missing_decimals);

        require(COLLATERAL_out_min <= collateral_precision, "Slippage limit reached");
        // Give the sender their desired collateral and burn the Gr
        Gr.pool_burn_from(msg.sender, Gr_amount);
        TransferHelper.safeTransfer(address(collateral_token), msg.sender, collateral_precision);
        TransferHelper.safeTransfer(address(collateral_token), devAddr, fee);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function toggleMinting() external {
        require(hasRole(MINT_PAUSER, msg.sender));
        mintPaused = !mintPaused;

        emit MintingToggled(mintPaused);
    }

    function toggleRedeeming() external {
        require(hasRole(REDEEM_PAUSER, msg.sender));
        redeemPaused = !redeemPaused;

        emit RedeemingToggled(redeemPaused);
    }

    function toggleRecollateralize() external {
        require(hasRole(RECOLLATERALIZE_PAUSER, msg.sender));
        recollateralizePaused = !recollateralizePaused;

        emit RecollateralizeToggled(recollateralizePaused);
    }

    function toggleBuyBack() external {
        require(hasRole(BUYBACK_PAUSER, msg.sender));
        buyBackPaused = !buyBackPaused;

        emit BuybackToggled(buyBackPaused);
    }

    function toggleCollateralPrice(uint256 _new_price) external {
        require(hasRole(COLLATERAL_PRICE_PAUSER, msg.sender));
        // If pausing, set paused price; else if unpausing, clear pausedPrice
        if(collateralPricePaused == false){
            pausedPrice = _new_price;
        } else {
            pausedPrice = 0;
        }
        collateralPricePaused = !collateralPricePaused;

        emit CollateralPriceToggled(collateralPricePaused);
    }

    function togglePriceVerify() external onlyByOwnGov {
        priceVerify = !priceVerify;

        emit PriceVerifyToggled(priceVerify);
    }

    // Combined into one function due to 24KiB contract memory limit
    function setPoolParameters(uint256 new_ceiling, uint256 new_bonus_rate, uint256 new_redemption_delay, uint256 new_mint_fee, uint256 new_redeem_fee, uint256 new_buyback_fee, uint256 new_recollat_fee) external onlyByOwnGov {
        require(new_ceiling > 0);
        pool_ceiling = new_ceiling;
        bonus_rate = new_bonus_rate;
        redemption_delay = new_redemption_delay;
        minting_fee = new_mint_fee;
        redemption_fee = new_redeem_fee;
        buyback_fee = new_buyback_fee;
        recollat_fee = new_recollat_fee;

        emit PoolParametersSet(new_ceiling, new_bonus_rate, new_redemption_delay, new_mint_fee, new_redeem_fee, new_buyback_fee, new_recollat_fee);
    }

    function setPriceThresholds(uint256 new_mint_price_threshold, uint256 new_redeem_price_threshold) external onlyByOwnGov {
        require(new_mint_price_threshold > new_redeem_price_threshold, "The foundry price must be greater than the redemption price");
        mint_price_threshold = new_mint_price_threshold;
        redeem_price_threshold = new_redeem_price_threshold;
        emit PriceThresholdsSet(new_mint_price_threshold, new_redeem_price_threshold);
    }

    function setTimelock(address new_timelock) external onlyByOwnGov {
        timelock_address = new_timelock;

        emit TimelockSet(new_timelock);
    }

    function setDevAddr(address new_devAddr) external onlyByOwnGov {
        devAddr = new_devAddr;

        emit DevAddrSet(new_devAddr);
    }

    /* ========== EVENTS ========== */

    event PoolParametersSet(uint256 new_ceiling, uint256 new_bonus_rate, uint256 new_redemption_delay, uint256 new_mint_fee, uint256 new_redeem_fee, uint256 new_buyback_fee, uint256 new_recollat_fee);
    event TimelockSet(address new_timelock);
    event DevAddrSet(address new_devAddr);
    event PriceThresholdsSet(uint256 new_mint_price_threshold, uint256 new_redeem_price_threshold);
    event MintingToggled(bool toggled);
    event RedeemingToggled(bool toggled);
    event BNBCollatOracleSet(address bnb_collat_consumer_address);
    event RecollateralizeToggled(bool toggled);
    event BuybackToggled(bool toggled);
    event PriceVerifyToggled(bool toggled);
    event CollateralPriceToggled(bool toggled);

}