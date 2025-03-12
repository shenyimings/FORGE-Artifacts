// SPDX-License-Identifier: Unlicensed

pragma solidity 0.7.6;

import "../../interface/IOneTokenV1.sol";
import "../../_openzeppelin/token/ERC20/SafeERC20.sol";
import "./OneTokenV1Base.sol";

contract OneTokenV1 is IOneTokenV1, OneTokenV1Base {

    using AddressSet for AddressSet.Set;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public override mintingFee; // defaults to 0%
    uint256 public override redemptionFee; // defaults to 0%

    /**
     @notice sum of userBalances for each collateral token are not counted in treasury valuations
     @dev token => liability
     */
    mapping(address => uint256) public liabilities;
  
    event Minted(address indexed sender, address indexed collateral, uint256 oneTokens, uint256 memberTokens, uint256 collateralTokens);
    event Redeemed(address indexed sender, address indexed collateral, uint256 amount);
    event NewMintingFee(address sender, uint256 fee);
    event NewRedemptionFee(address sender, uint256 fee);
    
    /// @dev there is no constructor for proxy deployment. Use init()

    /**
     @notice convert member tokens and collateral tokens into oneTokens. requires sufficient allowances for both tokens
     @dev takes the lessor of memberTokens allowance or the maximum allowed by the minting ratio and the balance in collateral
     @param collateralToken a registered ERC20 collateral token contract
     @param oneTokens exact number of oneTokens to receive
     */
    function mint(address collateralToken, uint256 oneTokens) external initialized override {
        require(collateralTokenSet.exists(collateralToken), "OTV1: offer a collateral token");
        require(oneTokens > 0, "OTV1: order must be > 0");
        
        // update collateral and memberToken oracles
        IOracle(assets[collateralToken].oracle).update(collateralToken);
        IOracle(assets[memberToken].oracle).update(memberToken);
        
        // update oneToken oracle and evaluate
        (uint256 mintingRatio, uint256 maxOrderVolume) = updateMintingRatio(collateralToken);

        // future mintmasters may return a maximum order volume to tamp down on possible manipulation
        require(oneTokens <= maxOrderVolume, "OTV1: order exceeds limit");

        // compute the member token value and collateral value requirement
        uint256 collateralUSDValue = oneTokens.mul(mintingRatio).div(PRECISION);
        uint256 memberTokensUSDValue = oneTokens.sub(collateralUSDValue);
        collateralUSDValue = collateralUSDValue.add(oneTokens.mul(mintingFee).div(PRECISION));

        // compute the member tokens required
        (uint256 memberTokensReq, /* volatility */) = IOracle(assets[memberToken].oracle).amountRequired(memberToken, memberTokensUSDValue);

        // check the memberToken allowance - the maximum we can draw from the user
        uint256 memberTokenAllowance = IERC20(memberToken).allowance(msg.sender, address(this));

        // increase collateral required if the memberToken allowance is too low
        if(memberTokensReq > memberTokenAllowance) {
            uint256 memberTokenRate = memberTokensUSDValue.mul(PRECISION).div(memberTokensReq);
            memberTokensReq = memberTokenAllowance;
            // re-evaluate the memberToken value and collateral value required using the oracle rate already obtained
            memberTokensUSDValue = memberTokenRate.mul(memberTokensReq).div(PRECISION);
            collateralUSDValue = oneTokens.sub(memberTokensUSDValue);
            collateralUSDValue = collateralUSDValue.add(oneTokens.mul(mintingFee).div(PRECISION));
        }

        require(IERC20(memberToken).balanceOf(msg.sender) >= memberTokensReq, "OTV1: NSF: member token");

        // compute actual collateral tokens required in case of imperfect collateral pegs
        // a pegged oracle can be used to reduce the cost of this step but it will not account for price differences
        (uint256 collateralTokensReq, /* volatility */) = IOracle(assets[collateralToken].oracle).amountRequired(collateralToken, collateralUSDValue);

        require(IERC20(collateralToken).balanceOf(msg.sender) >= collateralTokensReq, "OTV1: NSF: collateral token");
        require(collateralTokensReq > 0, "OTV1: order too small");

        // transfer tokens in
        IERC20(memberToken).safeTransferFrom(msg.sender, address(this), memberTokensReq);
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralTokensReq);
        
        // mint oneTokens
        _mint(msg.sender, oneTokens);

        emit Minted(msg.sender, collateralToken, oneTokens, memberTokensReq, collateralTokensReq);
    }

    /**
     @notice redeem oneTokens for collateral tokens at 1:1 - applies fee %
     @dev first grant allowances, then redeem. Consider infinite collateral allowance and a sufficient memberToken allowance. Updates ratio and triggers controller.
     @param collateral form of ERC20 stable token to receive
     @param amount oneTokens to redeem equals collateral tokens to receive
     */
    function redeem(address collateral, uint256 amount) external override {
        require(isCollateral(collateral), "OTV1: unknown collateral");
        require(amount > 0, "OTV1: amount must be > 0");
        require(balanceOf(msg.sender) >= amount, "OTV1: NSF: oneToken");
        IOracle co = IOracle(assets[collateral].oracle);
        co.update(collateral);

        // implied transfer approval and allowance
        _burn(msg.sender, amount);

        uint256 netUsd = amount.sub(amount.mul(redemptionFee).div(PRECISION));
        (uint256 netTokens, /* uint256 volatility */)  = co.amountRequired(collateral, netUsd);

        IERC20(collateral).safeTransfer(msg.sender, netTokens);
        emit Redeemed(msg.sender, collateral, amount);
        
        // updates the oneToken oracle price history
        updateMintingRatio(collateral);

        // periodic automated processes
        IController(controller).periodic();
    }

    /**
     @notice governance sets the adjustable fee
     @param fee fee, 18 decimals, e.g. 2% = 20000000000000000
     */
    function setMintingFee(uint256 fee) external onlyOwner override {
        require(fee <= PRECISION, "OTV1: fee must be <= 100%");
        mintingFee = fee;
        emit NewMintingFee(msg.sender, fee);
    }

    /**
     @notice governance sets the adjustable fee
     @param fee fee, 18 decimals, e.g. 2% = 20000000000000000
     */
    function setRedemptionFee(uint256 fee) external onlyOwner override {
        require(fee <= PRECISION, "OTV1: fee must be <= 100%");
        redemptionFee = fee;
        emit NewRedemptionFee(msg.sender, fee);
    }    

    /**
     @notice adjust the minting ratio
     @dev acceptable for gas-paying external actors to call this function
     @param collateralToken token to use for ratio calculation
     @param ratio minting ratio
     @param maxOrderVolume maximum order size
     */
    function updateMintingRatio(address collateralToken) public override returns(uint256 ratio, uint256 maxOrderVolume) {
        return IMintMaster(mintMaster).updateMintingRatio(collateralToken);
    }

    /**
     @notice read the minting ratio and maximum order volume prescribed by the mintMaster
     @param collateralToken token to use for ratio calculation
     @param ratio minting ratio
     @param maxOrderVolume maximum order size
     */
    function getMintingRatio(address collateralToken) external view override returns(uint256 ratio, uint256 maxOrderVolume) {
        return IMintMaster(mintMaster).getMintingRatio(collateralToken);
    }

    /**
     @notice read the vault balance and strategy balance of a given token
     @dev not restricted to registered assets
     @param token ERC20 asset to report
     @param vaultBalance tokens held in this vault
     @param strategyBalance tokens in assigned strategy
     */
    function getHoldings(address token) external view override returns(uint256 vaultBalance, uint256 strategyBalance) {   
        IERC20 t = IERC20(token);
        vaultBalance = t.balanceOf(address(this));
        Asset storage a = assets[token];
        if(a.strategy != NULL_ADDRESS) strategyBalance = t.balanceOf(a.strategy);
    } 
}
