// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;
pragma experimental ABIEncoderV2;

import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IProtocolAdapter, ProtocolAdapterTypes} from "./IProtocolAdapter.sol";
import {
    IOtokenFactory,
    OtokenInterface,
    IController,
    OracleInterface,
    GammaTypes
} from "../interfaces/GammaInterface.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router.sol";
import {DSMath} from "../lib/DSMath.sol";

contract GammaAdapter is IProtocolAdapter, DSMath {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // gammaController is the top-level contract in Gamma protocol which allows users to perform multiple actions on their vaults and positions https://github.com/opynfinance/GammaProtocol/blob/master/contracts/Controller.sol
    address public immutable gammaController;

    // oTokenFactory is the factory contract used to spawn otokens. Used to lookup otokens.
    address public immutable oTokenFactory;

    // _swapWindow is the number of seconds in which a Uniswap swap is valid from block.timestamp.
    uint256 private constant SWAP_WINDOW = 900;

    string private constant _name = "OPYN_GAMMA";
    bool private constant _nonFungible = false;

    // https://github.com/opynfinance/GammaProtocol/blob/master/contracts/Otoken.sol#L70
    uint256 private constant OTOKEN_DECIMALS = 10**8;

    uint256 private constant SLIPPAGE_TOLERANCE = 0.75 ether;

    // MARGIN_POOL is Gamma protocol's collateral pool. Needed to approve collateral.safeTransferFrom for minting otokens. https://github.com/opynfinance/GammaProtocol/blob/master/contracts/MarginPool.sol
    address public immutable MARGIN_POOL;

    // USDCETHPriceFeed is the USDC/ETH Chainlink price feed used to perform swaps, as an alternative to getAmountsIn
    AggregatorV3Interface public immutable USDCETHPriceFeed;

    // UNISWAP_ROUTER is Uniswap's periphery contract for conducting trades. Using this contract is gas inefficient and should only used for convenience i.e. admin functions
    address public immutable UNISWAP_ROUTER;

    // WETH9 contract
    address public immutable WETH;

    // USDC is the strike asset in Gamma Protocol
    address public immutable USDC;

    // 0x proxy for performing buys
    address public immutable ZERO_EX_EXCHANGE_V3;

    /**
     * @notice Constructor for the GammaAdapter which initializes a few immutable variables to be used by instrument contracts.
     * @param _oTokenFactory is the Gamma protocol factory contract which spawns otokens https://github.com/opynfinance/GammaProtocol/blob/master/contracts/OtokenFactory.sol
     * @param _gammaController is a top-level contract which allows users to perform multiple actions in the Gamma protocol https://github.com/opynfinance/GammaProtocol/blob/master/contracts/Controller.sol
     */
    constructor(
        address _oTokenFactory,
        address _gammaController,
        address _marginPool,
        address _usdcEthPriceFeed,
        address _uniswapRouter,
        address _weth,
        address _usdc,
        address _zeroExExchange
    ) {
        require(_oTokenFactory != address(0), "!_oTokenFactory");
        require(_gammaController != address(0), "!_gammaController");
        require(_marginPool != address(0), "!_marginPool");
        require(_usdcEthPriceFeed != address(0), "!_usdcEthPriceFeed");
        require(_uniswapRouter != address(0), "!_uniswapRouter");
        require(_weth != address(0), "!_weth");
        require(_usdc != address(0), "!_usdc");
        require(_zeroExExchange != address(0), "!_zeroExExchange");

        oTokenFactory = _oTokenFactory;
        gammaController = _gammaController;
        MARGIN_POOL = _marginPool;
        USDCETHPriceFeed = AggregatorV3Interface(_usdcEthPriceFeed);
        UNISWAP_ROUTER = _uniswapRouter;
        WETH = _weth;
        USDC = _usdc;
        ZERO_EX_EXCHANGE_V3 = _zeroExExchange;
    }

    receive() external payable {}

    function protocolName() external pure override returns (string memory) {
        return _name;
    }

    function nonFungible() external pure override returns (bool) {
        return _nonFungible;
    }

    function purchaseMethod()
        external
        pure
        override
        returns (ProtocolAdapterTypes.PurchaseMethod)
    {
        return ProtocolAdapterTypes.PurchaseMethod.ZeroEx;
    }

    /**
     * @notice Check if an options contract exist based on the passed parameters.
     * @param optionTerms is the terms of the option contract
     */
    function optionsExist(ProtocolAdapterTypes.OptionTerms calldata optionTerms)
        external
        view
        override
        returns (bool)
    {
        return lookupOToken(optionTerms) != address(0);
    }

    /**
     * @notice Get the options contract's address based on the passed parameters
     * @param optionTerms is the terms of the option contract
     */
    function getOptionsAddress(
        ProtocolAdapterTypes.OptionTerms calldata optionTerms
    ) external view override returns (address) {
        return lookupOToken(optionTerms);
    }

    /**
     * @notice Gets the premium to buy `purchaseAmount` of the option contract in ETH terms.
     */
    function premium(ProtocolAdapterTypes.OptionTerms calldata, uint256)
        external
        pure
        override
        returns (uint256 cost)
    {
        return 0;
    }

    /**
     * @notice Amount of profit made from exercising an option contract abs(current price - strike price). 0 if exercising out-the-money.
     * @param options is the address of the options contract
     * @param amount is the amount of tokens or options contract to exercise. Only relevant for fungle protocols like Opyn
     */
    function exerciseProfit(
        address options,
        uint256,
        uint256 amount
    ) public view override returns (uint256 profit) {
        IController controller = IController(gammaController);
        OracleInterface oracle = OracleInterface(controller.oracle());
        OtokenInterface otoken = OtokenInterface(options);

        uint256 spotPrice = oracle.getPrice(otoken.underlyingAsset());
        uint256 strikePrice = otoken.strikePrice();
        bool isPut = otoken.isPut();

        if (!isPut && spotPrice <= strikePrice) {
            return 0;
        } else if (isPut && spotPrice >= strikePrice) {
            return 0;
        }

        return controller.getPayout(options, amount.div(10**10));
    }

    /**
     * @notice Helper function that returns true if the option can be exercised now.
     * @param options is the address of the otoken
     * @param amount is amount of otokens to exercise
     */
    function canExercise(
        address options,
        uint256,
        uint256 amount
    ) public view override returns (bool) {
        OtokenInterface otoken = OtokenInterface(options);

        address underlying = otoken.underlyingAsset();
        uint256 expiry = otoken.expiryTimestamp();

        if (!isSettlementAllowed(underlying, expiry)) {
            return false;
        }
        // use `0` as the optionID because it doesn't do anything for exerciseProfit
        if (exerciseProfit(options, 0, amount) > 0) {
            return true;
        }
        return false;
    }

    /**
     * @notice Stubbed out for conforming to the IProtocolAdapter interface.
     */
    function purchase(
        ProtocolAdapterTypes.OptionTerms calldata,
        uint256,
        uint256
    ) external payable override returns (uint256) {}

    /**
     * @notice Purchases otokens using a 0x order struct
     * It is the obligation of the delegate-calling contract to return the remaining
     * msg.value back to the user.
     * @param optionTerms is the terms of the option contract
     * @param zeroExOrder is the 0x order struct constructed using the 0x API response passed by the frontend.
     */
    function purchaseWithZeroEx(
        ProtocolAdapterTypes.OptionTerms calldata optionTerms,
        ProtocolAdapterTypes.ZeroExOrder calldata zeroExOrder
    ) external payable {
        require(
            msg.value >= zeroExOrder.protocolFee,
            "Value cannot cover protocolFee"
        );
        require(
            zeroExOrder.sellTokenAddress == USDC,
            "Sell token has to be USDC"
        );

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_ROUTER);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = zeroExOrder.sellTokenAddress;

        (, int256 latestPrice, , , ) = USDCETHPriceFeed.latestRoundData();

        // Because we guard that zeroExOrder.sellTokenAddress == USDC
        // We can assume that the decimals == 6
        uint256 soldETH =
            zeroExOrder.takerAssetAmount.mul(uint256(latestPrice)).div(
                10**assetDecimals(zeroExOrder.sellTokenAddress)
            );

        router.swapETHForExactTokens{value: soldETH}(
            zeroExOrder.takerAssetAmount,
            path,
            address(this),
            block.timestamp + SWAP_WINDOW
        );

        require(
            IERC20(zeroExOrder.sellTokenAddress).balanceOf(address(this)) >=
                zeroExOrder.takerAssetAmount,
            "Not enough takerAsset balance"
        );

        // double approve to fix non-compliant ERC20s
        IERC20(zeroExOrder.sellTokenAddress).safeApprove(
            zeroExOrder.allowanceTarget,
            0
        );
        IERC20(zeroExOrder.sellTokenAddress).safeApprove(
            zeroExOrder.allowanceTarget,
            zeroExOrder.takerAssetAmount
        );

        require(
            address(this).balance >= zeroExOrder.protocolFee,
            "Not enough balance for protocol fee"
        );

        (bool success, ) =
            ZERO_EX_EXCHANGE_V3.call{value: zeroExOrder.protocolFee}(
                zeroExOrder.swapData
            );

        require(success, "0x swap failed");

        require(
            IERC20(zeroExOrder.buyTokenAddress).balanceOf(address(this)) >=
                zeroExOrder.makerAssetAmount,
            "Not enough buyToken balance"
        );

        emit Purchased(
            msg.sender,
            _name,
            optionTerms.underlying,
            soldETH.add(zeroExOrder.protocolFee),
            0
        );
    }

    /**
     * @notice Exercises the options contract.
     * @param options is the address of the options contract
     * @param amount is the amount of tokens or options contract to exercise. Only relevant for fungle protocols like Opyn
     * @param recipient is the account that receives the exercised profits. This is needed since the adapter holds all the positions and the msg.sender is an instrument contract.
     */
    function exercise(
        address options,
        uint256,
        uint256 amount,
        address recipient
    ) public payable override {
        OtokenInterface otoken = OtokenInterface(options);

        require(
            block.timestamp >= otoken.expiryTimestamp(),
            "oToken not expired yet"
        );

        // Since we accept all amounts in 10**18, we need to normalize it down to the decimals otokens use (10**8)
        uint256 scaledAmount = amount.div(10**10);

        // use `0` as the optionID because it doesn't do anything for exerciseProfit
        uint256 profit = exerciseProfit(options, 0, amount);

        require(profit > 0, "Not profitable to exercise");

        IController.ActionArgs memory action =
            IController.ActionArgs(
                IController.ActionType.Redeem,
                address(this), // owner
                address(this), // receiver -  we need this contract to receive so we can swap at the end
                options, // asset, otoken
                0, // vaultId
                scaledAmount,
                0, //index
                "" //data
            );

        IController.ActionArgs[] memory actions =
            new IController.ActionArgs[](1);
        actions[0] = action;

        IController(gammaController).operate(actions);

        uint256 profitInUnderlying =
            swapExercisedProfitsToUnderlying(options, profit, recipient);

        emit Exercised(msg.sender, options, 0, amount, profitInUnderlying);
    }

    /**
     * @notice Swaps the exercised profit (originally in the collateral token) into the `underlying` token.
     *         This simplifies the payout of an option. Put options pay out in USDC, so we swap USDC back
     *         into WETH and transfer it to the recipient.
     * @param otokenAddress is the otoken's address
     * @param profitInCollateral is the profit after exercising denominated in the collateral - this could be a token with different decimals
     * @param recipient is the recipient of the underlying tokens after the swap
     */
    function swapExercisedProfitsToUnderlying(
        address otokenAddress,
        uint256 profitInCollateral,
        address recipient
    ) internal returns (uint256 profitInUnderlying) {
        OtokenInterface otoken = OtokenInterface(otokenAddress);
        address collateral = otoken.collateralAsset();
        IERC20 collateralToken = IERC20(collateral);

        require(
            collateralToken.balanceOf(address(this)) >= profitInCollateral,
            "Not enough collateral from exercising"
        );

        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_ROUTER);

        IWETH weth = IWETH(WETH);

        if (collateral == address(weth)) {
            profitInUnderlying = profitInCollateral;
            weth.withdraw(profitInCollateral);
            (bool success, ) = recipient.call{value: profitInCollateral}("");
            require(success, "Failed to transfer exercise profit");
        } else {
            // just guard against anything that's not USDC
            // we will revisit opening up other collateral types for puts
            // when they get added
            require(collateral == USDC, "!USDC");

            address[] memory path = new address[](2);
            path[0] = collateral;
            path[1] = address(weth);

            (, int256 latestPrice, , , ) = USDCETHPriceFeed.latestRoundData();

            profitInUnderlying = wdiv(profitInCollateral, uint256(latestPrice))
                .mul(10**assetDecimals(collateral));

            require(profitInUnderlying > 0, "Swap is unprofitable");

            collateralToken.safeApprove(UNISWAP_ROUTER, 0);
            collateralToken.safeApprove(UNISWAP_ROUTER, profitInCollateral);

            uint256[] memory amountsOut =
                router.swapExactTokensForETH(
                    profitInCollateral,
                    wmul(profitInUnderlying, SLIPPAGE_TOLERANCE),
                    path,
                    recipient,
                    block.timestamp + SWAP_WINDOW
                );

            profitInUnderlying = amountsOut[1];
        }
    }

    /**
     * @notice Creates a short otoken position by opening a vault, depositing collateral and minting otokens.
     * The sale of otokens is left to the caller contract to perform.
     * @param optionTerms is the terms of the option contract
     * @param depositAmount is the amount deposited to open the vault. This amount will determine how much otokens to mint.
     */
    function createShort(
        ProtocolAdapterTypes.OptionTerms calldata optionTerms,
        uint256 depositAmount
    ) external override returns (uint256) {
        IController controller = IController(gammaController);
        uint256 newVaultID =
            (controller.getAccountVaultCounter(address(this))).add(1);

        address oToken = lookupOToken(optionTerms);
        require(oToken != address(0), "Invalid oToken");

        address collateralAsset = optionTerms.collateralAsset;
        if (collateralAsset == address(0)) {
            collateralAsset = WETH;
        }
        IERC20 collateralToken = IERC20(collateralAsset);

        uint256 collateralDecimals = assetDecimals(collateralAsset);
        uint256 mintAmount;

        if (optionTerms.optionType == ProtocolAdapterTypes.OptionType.Call) {
            mintAmount = depositAmount;
            if (collateralDecimals >= 8) {
                uint256 scaleBy = 10**(collateralDecimals - 8); // oTokens have 8 decimals
                mintAmount = depositAmount.div(scaleBy); // scale down from 10**18 to 10**8
                require(
                    mintAmount > 0,
                    "Must deposit more than 10**8 collateral"
                );
            }
        } else {
            mintAmount = wdiv(depositAmount, optionTerms.strikePrice)
                .mul(OTOKEN_DECIMALS)
                .div(10**collateralDecimals);
        }

        // double approve to fix non-compliant ERC20s
        collateralToken.safeApprove(MARGIN_POOL, 0);
        collateralToken.safeApprove(MARGIN_POOL, depositAmount);

        IController.ActionArgs[] memory actions =
            new IController.ActionArgs[](3);

        actions[0] = IController.ActionArgs(
            IController.ActionType.OpenVault,
            address(this), // owner
            address(this), // receiver -  we need this contract to receive so we can swap at the end
            address(0), // asset, otoken
            newVaultID, // vaultId
            0, // amount
            0, //index
            "" //data
        );

        actions[1] = IController.ActionArgs(
            IController.ActionType.DepositCollateral,
            address(this), // owner
            address(this), // address to transfer from
            collateralAsset, // deposited asset
            newVaultID, // vaultId
            depositAmount, // amount
            0, //index
            "" //data
        );

        actions[2] = IController.ActionArgs(
            IController.ActionType.MintShortOption,
            address(this), // owner
            address(this), // address to transfer to
            oToken, // deposited asset
            newVaultID, // vaultId
            mintAmount, // amount
            0, //index
            "" //data
        );

        controller.operate(actions);

        return mintAmount;
    }

    /**
     * @notice Close the existing short otoken position. Currently this implementation is simple.
     * It closes the most recent vault opened by the contract. This assumes that the contract will
     * only have a single vault open at any given time. Since calling `closeShort` deletes vaults,
     * this assumption should hold.
     */
    function closeShort() external override returns (uint256) {
        IController controller = IController(gammaController);

        // gets the currently active vault ID
        uint256 vaultID = controller.getAccountVaultCounter(address(this));

        GammaTypes.Vault memory vault =
            controller.getVault(address(this), vaultID);

        require(vault.shortOtokens.length > 0, "No active short");

        IERC20 collateralToken = IERC20(vault.collateralAssets[0]);
        OtokenInterface otoken = OtokenInterface(vault.shortOtokens[0]);

        bool settlementAllowed =
            isSettlementAllowed(
                otoken.underlyingAsset(),
                otoken.expiryTimestamp()
            );

        uint256 startCollateralBalance =
            collateralToken.balanceOf(address(this));

        IController.ActionArgs[] memory actions;

        // If it is after expiry, we need to settle the short position using the normal way
        // Delete the vault and withdraw all remaining collateral from the vault
        //
        // If it is before expiry, we need to burn otokens in order to withdraw collateral from the vault
        if (settlementAllowed) {
            actions = new IController.ActionArgs[](1);

            actions[0] = IController.ActionArgs(
                IController.ActionType.SettleVault,
                address(this), // owner
                address(this), // address to transfer to
                address(0), // not used
                vaultID, // vaultId
                0, // not used
                0, // not used
                "" // not used
            );

            controller.operate(actions);
        } else {
            // Burning otokens given by vault.shortAmounts[0] (closing the entire short position),
            // then withdrawing all the collateral from the vault
            actions = new IController.ActionArgs[](2);

            actions[0] = IController.ActionArgs(
                IController.ActionType.BurnShortOption,
                address(this), // owner
                address(this), // address to transfer to
                address(otoken), // otoken address
                vaultID, // vaultId
                vault.shortAmounts[0], // amount
                0, //index
                "" //data
            );

            actions[1] = IController.ActionArgs(
                IController.ActionType.WithdrawCollateral,
                address(this), // owner
                address(this), // address to transfer to
                address(collateralToken), // withdrawn asset
                vaultID, // vaultId
                vault.collateralAmounts[0], // amount
                0, //index
                "" //data
            );

            controller.operate(actions);
        }

        uint256 endCollateralBalance = collateralToken.balanceOf(address(this));

        return endCollateralBalance.sub(startCollateralBalance);
    }

    /**
     * @notice Gas-optimized getter for checking if settlement is allowed. Looks up from the oracles with asset address and expiry
     * @param underlying is the address of the underlying for an otoken
     * @param expiry is the timestamp of the otoken's expiry
     */
    function isSettlementAllowed(address underlying, uint256 expiry)
        private
        view
        returns (bool)
    {
        IController controller = IController(gammaController);
        OracleInterface oracle = OracleInterface(controller.oracle());

        bool underlyingFinalized =
            oracle.isDisputePeriodOver(underlying, expiry);

        bool strikeFinalized = oracle.isDisputePeriodOver(USDC, expiry);

        // We can avoid checking the dispute period for the collateral for now
        // Because the collateral is either the underlying or USDC at this point
        // We do not have, for example, ETH-collateralized UNI otoken vaults
        // bool collateralFinalized = oracle.isDisputePeriodOver(isPut ? USDC : underlying, expiry);

        return underlyingFinalized && strikeFinalized;
    }

    /**
     * @notice Helper function to get the decimals of an asset. Will just hardcode for the time being.
     * @param asset is the token which we want to know the decimals
     */
    function assetDecimals(address asset) private view returns (uint256) {
        // USDC
        if (asset == USDC) {
            return 6;
        }
        return 18;
    }

    /**
     * @notice Function to lookup oToken addresses. oToken addresses are keyed by an ABI-encoded byte string
     * @param optionTerms is the terms of the option contract
     */
    function lookupOToken(ProtocolAdapterTypes.OptionTerms memory optionTerms)
        public
        view
        returns (address oToken)
    {
        IOtokenFactory factory = IOtokenFactory(oTokenFactory);

        bool isPut =
            optionTerms.optionType == ProtocolAdapterTypes.OptionType.Put;
        address underlying = optionTerms.underlying;

        /**
         * In many instances, we just use 0x0 to indicate ETH as the underlying asset.
         * We need to unify usage of 0x0 as WETH instead.
         */
        if (optionTerms.underlying == address(0)) {
            underlying = WETH;
        }

        // Put otokens have USDC as the backing collateral
        // so we can ignore the collateral asset passed in option terms
        address collateralAsset;
        if (isPut) {
            collateralAsset = USDC;
        } else {
            collateralAsset = underlying;
        }

        oToken = factory.getOtoken(
            underlying,
            optionTerms.strikeAsset,
            collateralAsset,
            optionTerms.strikePrice.div(10**10),
            optionTerms.expiry,
            isPut
        );
    }
}
