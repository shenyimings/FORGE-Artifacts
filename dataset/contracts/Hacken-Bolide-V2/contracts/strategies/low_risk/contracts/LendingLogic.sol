// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "./BaseLogic.sol";
import "./interfaces/IXToken.sol";
import "./interfaces/ILogicContract.sol";
import "./interfaces/ICompound.sol";

abstract contract LendingLogic is ILendingLogic, BaseLogic {
    address public comptroller;
    address public rainMaker;

    address internal xETH;
    mapping(address => bool) internal usedXTokens;
    mapping(address => address) internal XTokens;

    event AddXToken(address token, address xToken);

    function __LendingLogic_init(address _comptroller, address _rainMaker)
        public
        initializer
    {
        __LendingLogic_init__inherited(_comptroller, _rainMaker);
    }

    function __LendingLogic_init__inherited(
        address _comptroller,
        address _rainMaker
    ) public onlyInitializing {
        UpgradeableBase.initialize();

        comptroller = _comptroller;
        rainMaker = _rainMaker;
    }

    modifier isUsedXToken(address xToken) {
        require(usedXTokens[xToken], "E2");
        _;
    }

    /*** Owner function ***/

    /**
     * @notice Add XToken in Contract and approve token  for storage, venus,
     * pancakeswap/apeswap router, and pancakeswap/apeswap master(Main Staking contract)
     * @param token Address of Token for deposited
     * @param xToken Address of XToken
     */
    function addXTokens(address token, address xToken)
        public
        virtual
        onlyOwnerAndAdmin
    {
        require(xToken != ZERO_ADDRESS, "E20");
        require(_checkMarkets(xToken), "E5");

        if ((token) != ZERO_ADDRESS) {
            IERC20Upgradeable(token).approve(xToken, type(uint256).max);
            IERC20Upgradeable(token).approve(
                multiLogicProxy,
                type(uint256).max
            );
            approveTokenForSwap(swapGateway, token);

            XTokens[token] = xToken;
        } else {
            xETH = xToken;
        }

        usedXTokens[xToken] = true;
        emit AddXToken(token, xToken);
    }

    function getXToken(address token) public view returns (address) {
        return XTokens[token];
    }

    function isXTokenUsed(address xToken) public view returns (bool) {
        return usedXTokens[xToken];
    }

    /*** LendingSystem function ***/

    /**
     * @notice Get all entered xTokens to comptroller
     */
    function getAllMarkets() external view override returns (address[] memory) {
        return _getAllMarkets();
    }

    /**
     * @notice Enter into a list of markets(address of XTokens) - it is not an
     * error to enter the same market more than once.
     * @param xTokens The addresses of the xToken markets to enter.
     * @return For each market, returns an error code indicating whether or not it was entered.
     * Each is 0 on success, otherwise an Error code
     */
    function enterMarkets(address[] calldata xTokens)
        external
        override
        onlyOwnerAndAdmin
        returns (uint256[] memory)
    {
        return _enterMarkets(xTokens);
    }

    /**
     * @notice Check account entered market
     */
    function checkEnteredMarket(address xToken)
        external
        view
        override
        returns (bool)
    {
        return _checkEnteredMarket(xToken);
    }

    /**
     * @notice Every user accrues rewards for each block
     * Venus : XVS, Ola : BANANA, dForce : DF
     * they are supplying to or borrowing from the protocol.
     */
    function claim() external override onlyOwnerAndAdmin {
        // Get all markets
        address[] memory xTokens = _getEnteredMarkets();

        // Claim
        _claim(xTokens);
    }

    /**
     * @notice Stake token and mint XToken
     * @param xToken: that mint XTokens to this contract
     * @param mintAmount: The amount of the asset to be supplied, in units of the underlying asset.
     * @return 0 on success, otherwise an Error code
     */
    function mint(address xToken, uint256 mintAmount)
        external
        override
        isUsedXToken(xToken)
        onlyOwnerAndAdmin
        returns (uint256)
    {
        return _mint(xToken, mintAmount);
    }

    /**
     * @notice The borrow function transfers an asset from the protocol to the user and creates a
     * borrow balance which begins accumulating interest based on the Borrow Rate for the asset.
     * The amount borrowed must be less than the user's Account Liquidity and the market's
     * available liquidity.
     * @param xToken: that mint XTokens to this contract
     * @param borrowAmount: The amount of underlying to be borrow.
     * @return 0 on success, otherwise an Error code
     */
    function borrow(address xToken, uint256 borrowAmount)
        external
        override
        isUsedXToken(xToken)
        onlyOwnerAndAdmin
        returns (uint256)
    {
        return _borrow(xToken, borrowAmount);
    }

    /**
     * @notice The repay function transfers an asset into the protocol, reducing the user's borrow balance.
     * @param xToken: that mint XTokens to this contract
     * @param repayAmount: The amount of the underlying borrowed asset to be repaid.
     * A value of -1 (i.e. 2256 - 1) can be used to repay the full amount.
     * @return 0 on success, otherwise an Error code
     */
    function repayBorrow(address xToken, uint256 repayAmount)
        external
        override
        isUsedXToken(xToken)
        onlyOwnerAndAdmin
        returns (uint256)
    {
        return _repayBorrow(xToken, repayAmount);
    }

    /**
     * @notice The redeem underlying function converts xTokens into a specified quantity of the
     * underlying asset, and returns them to the user.
     * The amount of xTokens redeemed is equal to the quantity of underlying tokens received,
     * divided by the current Exchange Rate.
     * The amount redeemed must be less than the user's Account Liquidity and the market's
     * available liquidity.
     * @param xToken: that mint XTokens to this contract
     * @param redeemAmount: The amount of underlying to be redeemed.
     * @return 0 on success, otherwise an Error code
     */
    function redeemUnderlying(address xToken, uint256 redeemAmount)
        external
        virtual
        override
        isUsedXToken(xToken)
        onlyOwnerAndAdmin
        returns (uint256)
    {
        return _redeemUnderlying(xToken, redeemAmount);
    }

    /**
     * @notice The redeem function converts xTokens into a specified quantity of the
     * underlying asset, and returns them to the user.
     * The amount of xTokens redeemed is equal to the quantity of underlying tokens received,
     * divided by the current Exchange Rate.
     * The amount redeemed must be less than the user's xToken baalance.
     * @param xToken: that mint XTokens to this contract
     * @param redeemTokenAmount: The amount of underlying to be redeemed.
     * @return 0 on success, otherwise an Error code
     */
    function redeem(address xToken, uint256 redeemTokenAmount)
        external
        virtual
        override
        isUsedXToken(xToken)
        onlyOwnerAndAdmin
        returns (uint256)
    {
        return _redeem(xToken, redeemTokenAmount);
    }

    function rewardToken() external view override returns (address) {
        return _rewardToken();
    }

    function getUnderlying(address xToken)
        external
        view
        override
        returns (address)
    {
        return _getUnderlying(xToken);
    }

    function getUnderlyingPrice(address xToken)
        public
        view
        override
        isUsedXToken(xToken)
        returns (uint256)
    {
        return _getUnderlyingPrice(xToken);
    }

    function getCollateralFactor(address xToken)
        external
        view
        override
        returns (uint256)
    {
        return _getCollateralFactor(xToken);
    }

    /*** Private Virtual Function ***/

    /**
     * @notice Check if xToken is in market
     * for each strategy, this function should be override
     */
    function _checkMarkets(address xToken)
        internal
        view
        virtual
        returns (bool)
    {}

    /**
     * @notice enterMarket with xToken
     */
    function _enterMarkets(address[] calldata xTokens)
        internal
        virtual
        returns (uint256[] memory)
    {
        return IComptrollerCompound(comptroller).enterMarkets(xTokens);
    }

    /**
     * @notice AccurateInterest
     */
    function accrueInterest(address xToken) external virtual override {
        _accrueInterest(xToken);
    }

    /**
     * @notice Stake token and mint XToken
     */
    function _mint(address xToken, uint256 mintAmount)
        internal
        virtual
        returns (uint256)
    {
        if (xToken == xETH) {
            IXTokenETH(xToken).mint{value: mintAmount}();
            return 0;
        }

        return IXToken(xToken).mint(mintAmount);
    }

    /**
     * @notice borrow underlying token
     */
    function _borrow(address xToken, uint256 borrowAmount)
        internal
        virtual
        returns (uint256)
    {
        return IXToken(xToken).borrow(borrowAmount);
    }

    /**
     * @notice repayBorrow underlying token
     */
    function _repayBorrow(address xToken, uint256 repayAmount)
        internal
        virtual
        returns (uint256)
    {
        if (xToken == xETH) {
            IXTokenETH(xToken).repayBorrow{value: repayAmount}();
            return 0;
        }

        return IXToken(xToken).repayBorrow(repayAmount);
    }

    /**
     * @notice redeem underlying staked token
     */
    function _redeemUnderlying(address xToken, uint256 redeemAmount)
        internal
        virtual
        returns (uint256)
    {
        return IXToken(xToken).redeemUnderlying(redeemAmount);
    }

    /**
     * @notice redeem underlying staked token
     */
    function _redeem(address xToken, uint256 redeemTokenAmount)
        internal
        virtual
        returns (uint256)
    {
        return IXToken(xToken).redeem(redeemTokenAmount);
    }

    /**
     * @notice Claim strategy rewards token
     * for each strategy, this function should be override
     */
    function _claim(address[] memory xTokens) internal virtual {}

    /**
     * @notice Get all xTokens to comptroller
     */
    function _getAllMarkets() internal view virtual returns (address[] memory) {
        return IComptrollerCompound(comptroller).getAllMarkets();
    }

    /**
     * @notice Get all entered xTokens to comptroller
     */
    function _getEnteredMarkets()
        internal
        view
        virtual
        returns (address[] memory)
    {
        return IComptrollerCompound(comptroller).getAssetsIn(address(this));
    }

    /**
     * @notice Check account entered market
     */
    function _checkEnteredMarket(address xToken)
        internal
        view
        virtual
        returns (bool)
    {
        return
            IComptrollerCompound(comptroller).checkMembership(
                address(this),
                xToken
            );
    }

    function _rewardToken() internal view virtual returns (address) {}

    function _getUnderlyingPrice(address xToken)
        internal
        view
        virtual
        returns (uint256)
    {}

    function _getUnderlying(address xToken)
        internal
        view
        virtual
        returns (address)
    {
        return IXToken(xToken).underlying();
    }

    function _getCollateralFactor(address xToken)
        internal
        view
        virtual
        returns (uint256)
    {}

    /**
     * @notice accrueInterest
     */
    function _accrueInterest(address xToken) internal virtual {}
}
