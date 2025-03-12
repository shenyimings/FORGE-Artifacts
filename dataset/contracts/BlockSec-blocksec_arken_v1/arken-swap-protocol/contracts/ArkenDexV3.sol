// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.16;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import './interfaces/IBakeryPair.sol';
import './interfaces/IDODOV2.sol';
import './interfaces/IWETH.sol';
import './interfaces/IVyperSwap.sol';
import './interfaces/IVyperUnderlyingSwap.sol';
import './interfaces/ISaddleDex.sol';
import './interfaces/IDODOV2Proxy.sol';
import './interfaces/IBalancer.sol';
import './interfaces/ICurveTricryptoV2.sol';
import './interfaces/IArkenApprove.sol';
import './interfaces/IDMMPool.sol';
import './interfaces/IWooPP.sol';
import './lib/UniswapV2Library.sol';
import './lib/DMMLibrary.sol';
import './lib/UniswapV3CallbackValidation.sol';

// import 'hardhat/console.sol';

contract ArkenDexV3 is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 constant MAX_INT = 2**256 - 1;
    uint256 public constant _DEADLINE_ = 2**256 - 1;
    address public constant _ETH_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Uniswap V3
    uint160 internal constant MIN_SQRT_RATIO = 4295128739 + 1;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342 - 1;

    address payable public _FEE_WALLET_ADDR_;
    address public _DODO_APPROVE_ADDR_;
    address public _WETH_;
    address public _WETH_DFYN_;
    address public _ARKEN_APPROVE_;
    address public _UNISWAP_V3_FACTORY_;
    address public _WOOFI_QUOTE_TOKEN_;

    /*
    ==============================================================================

    █▀▀ █░█ █▀▀ █▄░█ ▀█▀ █▀
    ██▄ ▀▄▀ ██▄ █░▀█ ░█░ ▄█

    ==============================================================================
    */
    event Swapped(
        address srcToken,
        address dstToken,
        uint256 amountIn,
        uint256 returnAmount
    );
    event SwappedStopLimit(
        address srcToken,
        address dstToken,
        uint256 amountIn,
        uint256 returnAmount
    );
    event FeeWalletUpdated(address newFeeWallet);
    event WETHUpdated(address newWETH);
    event WETHDfynUpdated(address newWETHDfyn);
    event DODOApproveUpdated(address newDODOApproveAddress);
    event ArkenApproveUpdated(address newArkenApproveAddress);
    event UniswapV3FactoryUpdated(address newUv3Factory);
    event WooFiQuoteTokenUpdated(address newWooFiQuoteTokenAddress);

    /*
    ==============================================================================

    █▀▀ █▀█ █▄░█ █▀▀ █ █▀▀ █░█ █▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█ █▀
    █▄▄ █▄█ █░▀█ █▀░ █ █▄█ █▄█ █▀▄ █▀█ ░█░ █ █▄█ █░▀█ ▄█

    ==============================================================================
    */
    constructor(
        address _ownerAddress,
        address payable _feeWalletAddress,
        address _wrappedEther,
        address _wrappedEtherDfyn,
        address _dodoApproveAddress,
        address _arkenApprove,
        address _uniswapV3Factory,
        address _woofiQuoteToken
    ) {
        transferOwnership(_ownerAddress);
        _FEE_WALLET_ADDR_ = _feeWalletAddress;
        _DODO_APPROVE_ADDR_ = _dodoApproveAddress;
        _WETH_ = _wrappedEther;
        _WETH_DFYN_ = _wrappedEtherDfyn;
        _ARKEN_APPROVE_ = _arkenApprove;
        _UNISWAP_V3_FACTORY_ = _uniswapV3Factory;
        _WOOFI_QUOTE_TOKEN_ = _woofiQuoteToken;
    }

    receive() external payable {}

    fallback() external payable {}

    function updateFeeWallet(address payable _feeWallet) external onlyOwner {
        require(_feeWallet != address(0), 'fee wallet zero address');
        _FEE_WALLET_ADDR_ = _feeWallet;
        emit FeeWalletUpdated(_FEE_WALLET_ADDR_);
    }

    function updateWETH(address _weth) external onlyOwner {
        require(_weth != address(0), 'WETH zero address');
        _WETH_ = _weth;
        emit WETHUpdated(_WETH_);
    }

    function updateWETHDfyn(address _weth_dfyn) external onlyOwner {
        require(_weth_dfyn != address(0), 'WETH dfyn zero address');
        _WETH_DFYN_ = _weth_dfyn;
        emit WETHDfynUpdated(_WETH_DFYN_);
    }

    function updateDODOApproveAddress(address _dodoApproveAddress)
        external
        onlyOwner
    {
        require(_dodoApproveAddress != address(0), 'dodo approve zero address');
        _DODO_APPROVE_ADDR_ = _dodoApproveAddress;
        emit DODOApproveUpdated(_DODO_APPROVE_ADDR_);
    }

    function updateArkenApprove(address _arkenApprove) external onlyOwner {
        require(_arkenApprove != address(0), 'arken approve zero address');
        _ARKEN_APPROVE_ = _arkenApprove;
        emit ArkenApproveUpdated(_ARKEN_APPROVE_);
    }

    function updateUniswapV3Factory(address _uv3Factory) external onlyOwner {
        require(_uv3Factory != address(0), 'UniswapV3 Factory zero address');
        _UNISWAP_V3_FACTORY_ = _uv3Factory;
        emit UniswapV3FactoryUpdated(_UNISWAP_V3_FACTORY_);
    }

    function updateWoofiQuoteToken(address _woofiQuoteToken)
        external
        onlyOwner
    {
        require(
            _woofiQuoteToken != address(0),
            'WooFi quote token zero address'
        );
        _WOOFI_QUOTE_TOKEN_ = _woofiQuoteToken;
        emit WooFiQuoteTokenUpdated(_WOOFI_QUOTE_TOKEN_);
    }

    /*
    ==================================================================================

    ▀█▀ █▀█ ▄▀█ █▀▄ █▀▀ ░   ▀█▀ █▀█ ▄▀█ █▀▄ █▀▀ ░   ▀█▀ █▀█ ▄▀█ █▀▄ █▀▀ ░
    ░█░ █▀▄ █▀█ █▄▀ ██▄ ▄   ░█░ █▀▄ █▀█ █▄▀ ██▄ ▄   ░█░ █▀▄ █▀█ █▄▀ ██▄ ▄

    ==================================================================================
    */

    enum RouterInterface {
        UNISWAP_V2,
        BAKERY,
        VYPER,
        VYPER_UNDERLYING,
        SADDLE,
        DODO_V2,
        DODO_V1,
        DFYN,
        BALANCER,
        UNISWAP_V3,
        CURVE_TRICRYPTO_V2,
        LIMIT_ORDER_PROTOCOL_V2,
        KYBER_DMM,
        WOO_FI
    }
    struct TradeRoute {
        address routerAddress;
        address lpAddress;
        address fromToken;
        address toToken;
        address from;
        address to;
        uint32 part;
        uint8 direction; // DODO
        int16 fromTokenIndex; // Vyper
        int16 toTokenIndex; // Vyper
        uint16 amountAfterFee; // 9970 = fee 0.3% -- 10000 = no fee
        RouterInterface dexInterface; // uint8
    }
    struct TradeDescription {
        address srcToken;
        address dstToken;
        uint256 amountIn;
        uint256 amountOutMin;
        address payable to;
        TradeRoute[] routes;
        bool isRouterSource;
        bool isSourceFee;
    }
    struct TradeData {
        uint256 amountIn;
    }
    struct UniswapV3CallbackData {
        address token0;
        address token1;
        uint24 fee;
    }

    function trade(TradeDescription memory desc) external payable {
        require(desc.amountIn > 0, 'Amount-in needs to be more than zero');
        require(
            desc.amountOutMin > 0,
            'Amount-out minimum needs to be more than zero'
        );
        if (_ETH_ == desc.srcToken) {
            require(
                desc.amountIn == msg.value,
                'Ether value not match amount-in'
            );
            require(
                desc.isRouterSource,
                'Source token Ether requires isRouterSource=true'
            );
        }

        uint256 beforeDstAmt = _getBalance(desc.dstToken, desc.to);

        TradeData memory data = TradeData({amountIn: desc.amountIn});
        if (desc.isSourceFee) {
            if (_ETH_ == desc.srcToken) {
                data.amountIn = _collectFee(desc.amountIn, desc.srcToken);
            } else {
                uint256 fee = _calculateFee(desc.amountIn);
                require(fee < desc.amountIn, 'Fee exceeds amount');
                _transferFromSender(
                    desc.srcToken,
                    _FEE_WALLET_ADDR_,
                    fee,
                    desc.srcToken,
                    data
                );
            }
        }

        uint256 returnAmount = _trade(desc, data);

        if (!desc.isSourceFee) {
            require(
                returnAmount >= desc.amountOutMin && returnAmount > 0,
                'Return amount is not enough'
            );
            returnAmount = _collectFee(returnAmount, desc.dstToken);
        }

        if (returnAmount > 0) {
            if (_ETH_ == desc.dstToken) {
                (bool sent, ) = desc.to.call{value: returnAmount}('');
                require(sent, 'Failed to send Ether');
            } else {
                IERC20(desc.dstToken).safeTransfer(desc.to, returnAmount);
            }
        }

        uint256 receivedAmt = _getBalance(desc.dstToken, desc.to) -
            beforeDstAmt;
        require(
            receivedAmt >= desc.amountOutMin,
            'Received token is not enough'
        );

        emit Swapped(desc.srcToken, desc.dstToken, desc.amountIn, receivedAmt);
    }

    function tradeStopLimit(
        TradeDescription memory desc,
        uint256 stopLimitFee,
        uint256 minimumStopLimitFee
    ) external payable {
        require(desc.amountIn > 0, 'Amount-in needs to be more than zero');
        require(
            desc.amountOutMin > 0,
            'Amount-out minimum needs to be more than zero'
        );

        TradeData memory data = TradeData({amountIn: desc.amountIn});
        if (_ETH_ == desc.srcToken) {
            require(
                desc.amountIn == msg.value,
                'Ether value not match amount-in'
            );
            require(
                desc.isRouterSource,
                'Source token Ether requires isRouterSource=true'
            );
        } else {
            uint256 balanceSrcAmt = _getBalance(desc.srcToken, msg.sender);
            if (balanceSrcAmt < data.amountIn) {
                data.amountIn = balanceSrcAmt;
            }
        }
        require(stopLimitFee >= 10, 'Fee is too low');
        uint256 beforeDstAmt = _getBalance(desc.dstToken, desc.to);

        if (desc.isSourceFee) {
            if (_ETH_ == desc.srcToken) {
                data.amountIn = _collectStopLimitFee(
                    desc.amountIn,
                    desc.srcToken,
                    stopLimitFee,
                    minimumStopLimitFee
                );
            } else {
                uint256 feeAmount = _calculateStopLimitFee(
                    desc.amountIn,
                    stopLimitFee
                );
                if (feeAmount < minimumStopLimitFee) {
                    feeAmount = minimumStopLimitFee;
                }
                require(feeAmount < desc.amountIn, 'Fee exceeds amount');
                _transferFromSender(
                    desc.srcToken,
                    _FEE_WALLET_ADDR_,
                    feeAmount,
                    desc.srcToken,
                    data
                );
            }
        }

        uint256 returnAmount = _trade(desc, data);

        if (!desc.isSourceFee) {
            require(
                returnAmount >= desc.amountOutMin && returnAmount > 0,
                'Return amount is not enough'
            );
            returnAmount = _collectStopLimitFee(
                returnAmount,
                desc.dstToken,
                stopLimitFee,
                minimumStopLimitFee
            );
        }

        if (returnAmount > 0) {
            if (_ETH_ == desc.dstToken) {
                (bool sent, ) = desc.to.call{value: returnAmount}('');
                require(sent, 'Failed to send Ether');
            } else {
                IERC20(desc.dstToken).safeTransfer(desc.to, returnAmount);
            }
        }

        uint256 receivedAmt = _getBalance(desc.dstToken, desc.to) -
            beforeDstAmt;
        require(
            receivedAmt >= desc.amountOutMin,
            'Received token is not enough'
        );

        emit SwappedStopLimit(
            desc.srcToken,
            desc.dstToken,
            desc.amountIn,
            receivedAmt
        );
    }

    function _trade(TradeDescription memory desc, TradeData memory data)
        internal
        returns (uint256 returnAmount)
    {
        if (desc.isRouterSource && _ETH_ != desc.srcToken) {
            _transferFromSender(
                desc.srcToken,
                address(this),
                data.amountIn,
                desc.srcToken,
                data
            );
        }
        if (_ETH_ == desc.srcToken) {
            _wrapEther(_WETH_, address(this).balance);
        }

        for (uint256 i = 0; i < desc.routes.length; i++) {
            _tradeRoute(desc.routes[i], desc, data);
        }

        if (_ETH_ == desc.dstToken) {
            returnAmount = IERC20(_WETH_).balanceOf(address(this));
            _unwrapEther(_WETH_, returnAmount);
        } else {
            returnAmount = IERC20(desc.dstToken).balanceOf(address(this));
        }
    }

    /*

    █▀▄ █▀▀ ▀▄▀
    █▄▀ ██▄ █░█

    */

    function _tradeRoute(
        TradeRoute memory route,
        TradeDescription memory desc,
        TradeData memory data
    ) internal {
        require(
            route.part <= 100000000,
            'Route percentage can not exceed 100000000'
        );
        require(
            route.fromToken != _ETH_ && route.toToken != _ETH_,
            'TradeRoute from/to token cannot be Ether'
        );
        if (route.from == address(1)) {
            require(
                route.fromToken == desc.srcToken,
                'Cannot transfer token from msg.sender'
            );
        }
        if (
            !desc.isSourceFee &&
            (route.toToken == desc.dstToken ||
                (_ETH_ == desc.dstToken && _WETH_ == route.toToken))
        ) {
            require(
                route.to == address(0),
                'Destination swap have to be ArkenDex'
            );
        }
        uint256 amountIn;
        if (route.from == address(0)) {
            amountIn =
                (IERC20(
                    route.fromToken == _WETH_DFYN_ ? _WETH_ : route.fromToken
                ).balanceOf(address(this)) * route.part) /
                100000000;
        } else if (route.from == address(1)) {
            amountIn = (data.amountIn * route.part) / 100000000;
        }
        if (route.dexInterface == RouterInterface.UNISWAP_V2) {
            _tradeUniswapV2(route, amountIn, desc, data);
        } else if (route.dexInterface == RouterInterface.BAKERY) {
            _tradeBakery(route, amountIn, desc, data);
        } else if (route.dexInterface == RouterInterface.DODO_V2) {
            _tradeDODOV2(route, amountIn, desc, data);
        } else if (route.dexInterface == RouterInterface.DODO_V1) {
            _tradeDODOV1(route, amountIn);
        } else if (route.dexInterface == RouterInterface.DFYN) {
            _tradeDfyn(route, amountIn, desc, data);
        } else if (route.dexInterface == RouterInterface.VYPER) {
            _tradeVyper(route, amountIn);
        } else if (route.dexInterface == RouterInterface.VYPER_UNDERLYING) {
            _tradeVyperUnderlying(route, amountIn);
        } else if (route.dexInterface == RouterInterface.SADDLE) {
            _tradeSaddle(route, amountIn);
        } else if (route.dexInterface == RouterInterface.BALANCER) {
            _tradeBalancer(route, amountIn);
        } else if (route.dexInterface == RouterInterface.UNISWAP_V3) {
            _tradeUniswapV3(route, amountIn, desc);
        } else if (route.dexInterface == RouterInterface.CURVE_TRICRYPTO_V2) {
            _tradeCurveTricryptoV2(route, amountIn);
        } else if (route.dexInterface == RouterInterface.KYBER_DMM) {
            _tradeKyberDMM(route, amountIn, desc, data);
        } else if (route.dexInterface == RouterInterface.WOO_FI) {
            _tradeWooFi(route, amountIn, desc);
        } else {
            revert('unknown router interface');
        }
    }

    function _tradeWooFi(
        TradeRoute memory route,
        uint256 amountIn,
        TradeDescription memory desc
    ) internal {
        require(route.from == address(0), 'route.from should be zero address');

        IWooPP wooPool = IWooPP(route.lpAddress);

        _increaseAllowance(route.fromToken, route.lpAddress, amountIn);

        address to = route.to;
        if (to == address(0)) to = address(this);
        if (to == address(1)) to = desc.to;

        if (route.fromToken == _WOOFI_QUOTE_TOKEN_) {
            // case 1: quoteToken --> baseToken
            wooPool.sellQuote(
                route.toToken,
                amountIn,
                0,
                to,
                address(0)
            );
        } else if (route.toToken == _WOOFI_QUOTE_TOKEN_) {
            // case 2: fromToken --> quoteToken
            wooPool.sellBase(
                route.fromToken,
                amountIn,
                0,
                to,
                address(0)
            );
        } else {
            // case 3: fromToken --> quoteToken --> toToken
            uint256 quoteAmount = wooPool.sellBase(
                route.fromToken,
                amountIn,
                0,
                address(this),
                address(0)
            );

            _increaseAllowance(
                _WOOFI_QUOTE_TOKEN_,
                route.lpAddress,
                quoteAmount
            );

            wooPool.sellQuote(
                route.toToken,
                quoteAmount,
                0,
                to,
                address(0)
            );
        }
    }

    function _tradeKyberDMM(
        TradeRoute memory route,
        uint256 amountIn,
        TradeDescription memory desc,
        TradeData memory data
    ) internal {
        if (route.from == address(0)) {
            IERC20(route.fromToken).safeTransfer(route.lpAddress, amountIn);
        } else if (route.from == address(1)) {
            _transferFromSender(
                route.fromToken,
                route.lpAddress,
                amountIn,
                desc.srcToken,
                data
            );
        }
        IDMMPool pair = IDMMPool(route.lpAddress);
        (
            uint112 reserve0,
            uint112 reserve1,
            uint112 _vReserve0,
            uint112 _vReserve1,
            uint256 feeInPrecision
        ) = pair.getTradeInfo();
        if (route.fromToken != address(pair.token0())) {
            (reserve1, reserve0, _vReserve1, _vReserve0) = (
                reserve0,
                reserve1,
                _vReserve0,
                _vReserve1
            );
        }
        amountIn =
            IERC20(route.fromToken).balanceOf(route.lpAddress) -
            reserve0;
        uint256 amountOut = DMMLibrary.getAmountOut(
            amountIn,
            reserve0,
            reserve1,
            _vReserve0,
            _vReserve1,
            feeInPrecision
        );

        address to = route.to;
        if (to == address(0)) to = address(this);
        if (to == address(1)) to = desc.to;
        if (route.toToken == address(pair.token0())) {
            pair.swap(amountOut, 0, to, '');
        } else {
            pair.swap(0, amountOut, to, '');
        }
    }

    function _tradeUniswapV2(
        TradeRoute memory route,
        uint256 amountIn,
        TradeDescription memory desc,
        TradeData memory data
    ) internal {
        if (route.from == address(0)) {
            IERC20(route.fromToken).safeTransfer(route.lpAddress, amountIn);
        } else if (route.from == address(1)) {
            _transferFromSender(
                route.fromToken,
                route.lpAddress,
                amountIn,
                desc.srcToken,
                data
            );
        }
        IUniswapV2Pair pair = IUniswapV2Pair(route.lpAddress);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (uint256 reserveFrom, uint256 reserveTo) = route.fromToken ==
            pair.token0()
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        amountIn =
            IERC20(route.fromToken).balanceOf(route.lpAddress) -
            reserveFrom;
        uint256 amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveFrom,
            reserveTo,
            route.amountAfterFee
        );
        address to = route.to;
        if (to == address(0)) to = address(this);
        if (to == address(1)) to = desc.to;
        if (route.toToken == pair.token0()) {
            pair.swap(amountOut, 0, to, '');
        } else {
            pair.swap(0, amountOut, to, '');
        }
    }

    function _tradeDfyn(
        TradeRoute memory route,
        uint256 amountIn,
        TradeDescription memory desc,
        TradeData memory data
    ) internal {
        if (route.fromToken == _WETH_DFYN_) {
            _unwrapEther(_WETH_, amountIn);
            _wrapEther(_WETH_DFYN_, amountIn);
        }
        _tradeUniswapV2(route, amountIn, desc, data);
        if (route.toToken == _WETH_DFYN_) {
            uint256 amountOut = IERC20(_WETH_DFYN_).balanceOf(address(this));
            _unwrapEther(_WETH_DFYN_, amountOut);
            _wrapEther(_WETH_, amountOut);
        }
    }

    function _tradeBakery(
        TradeRoute memory route,
        uint256 amountIn,
        TradeDescription memory desc,
        TradeData memory data
    ) internal {
        if (route.from == address(0)) {
            IERC20(route.fromToken).safeTransfer(route.lpAddress, amountIn);
        } else if (route.from == address(1)) {
            _transferFromSender(
                route.fromToken,
                route.lpAddress,
                amountIn,
                desc.srcToken,
                data
            );
        }
        IBakeryPair pair = IBakeryPair(route.lpAddress);
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (uint256 reserveFrom, uint256 reserveTo) = route.fromToken ==
            pair.token0()
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        amountIn =
            IERC20(route.fromToken).balanceOf(route.lpAddress) -
            reserveFrom;
        uint256 amountOut = UniswapV2Library.getAmountOut(
            amountIn,
            reserveFrom,
            reserveTo,
            route.amountAfterFee
        );
        address to = route.to;
        if (to == address(0)) to = address(this);
        if (to == address(1)) to = desc.to;
        if (route.toToken == pair.token0()) {
            pair.swap(amountOut, 0, to);
        } else {
            pair.swap(0, amountOut, to);
        }
    }

    function _tradeUniswapV3(
        TradeRoute memory route,
        uint256 amountIn,
        TradeDescription memory desc
    ) internal {
        require(route.from == address(0), 'route.from should be zero address');
        IUniswapV3Pool pool = IUniswapV3Pool(route.lpAddress);
        bool zeroForOne = pool.token0() == route.fromToken;
        address to = route.to;
        if (to == address(0)) to = address(this);
        if (to == address(1)) to = desc.to;
        pool.swap(
            to,
            zeroForOne,
            int256(amountIn),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(
                UniswapV3CallbackData({
                    token0: pool.token0(),
                    token1: pool.token1(),
                    fee: pool.fee()
                })
            )
        );
    }

    function _tradeDODOV2(
        TradeRoute memory route,
        uint256 amountIn,
        TradeDescription memory desc,
        TradeData memory data
    ) internal {
        if (route.from == address(0)) {
            IERC20(route.fromToken).safeTransfer(route.lpAddress, amountIn);
        } else if (route.from == address(1)) {
            _transferFromSender(
                route.fromToken,
                route.lpAddress,
                amountIn,
                desc.srcToken,
                data
            );
        }
        address to = route.to;
        if (to == address(0)) to = address(this);
        if (to == address(1)) to = desc.to;
        if (IDODOV2(route.lpAddress)._BASE_TOKEN_() == route.fromToken) {
            IDODOV2(route.lpAddress).sellBase(to);
        } else {
            IDODOV2(route.lpAddress).sellQuote(to);
        }
    }

    function _tradeDODOV1(TradeRoute memory route, uint256 amountIn) internal {
        require(route.from == address(0), 'route.from should be zero address');
        _increaseAllowance(route.fromToken, _DODO_APPROVE_ADDR_, amountIn);
        address[] memory dodoPairs = new address[](1);
        dodoPairs[0] = route.lpAddress;
        IDODOV2Proxy(route.routerAddress).dodoSwapV1(
            route.fromToken,
            route.toToken,
            amountIn,
            1,
            dodoPairs,
            route.direction,
            false,
            _DEADLINE_
        );
    }

    function _tradeCurveTricryptoV2(TradeRoute memory route, uint256 amountIn)
        internal
    {
        require(route.from == address(0), 'route.from should be zero address');
        _increaseAllowance(route.fromToken, route.routerAddress, amountIn);
        ICurveTricryptoV2(route.routerAddress).exchange(
            uint16(route.fromTokenIndex),
            uint16(route.toTokenIndex),
            amountIn,
            0,
            false
        );
    }

    function _tradeVyper(TradeRoute memory route, uint256 amountIn) internal {
        require(route.from == address(0), 'route.from should be zero address');
        _increaseAllowance(route.fromToken, route.routerAddress, amountIn);
        IVyperSwap(route.routerAddress).exchange(
            route.fromTokenIndex,
            route.toTokenIndex,
            amountIn,
            0
        );
    }

    function _tradeVyperUnderlying(TradeRoute memory route, uint256 amountIn)
        internal
    {
        require(route.from == address(0), 'route.from should be zero address');
        _increaseAllowance(route.fromToken, route.routerAddress, amountIn);
        IVyperUnderlyingSwap(route.routerAddress).exchange_underlying(
            route.fromTokenIndex,
            route.toTokenIndex,
            amountIn,
            0
        );
    }

    function _tradeSaddle(TradeRoute memory route, uint256 amountIn) internal {
        require(route.from == address(0), 'route.from should be zero address');
        _increaseAllowance(route.fromToken, route.routerAddress, amountIn);
        ISaddleDex dex = ISaddleDex(route.routerAddress);
        uint8 tokenIndexFrom = dex.getTokenIndex(route.fromToken);
        uint8 tokenIndexTo = dex.getTokenIndex(route.toToken);
        dex.swap(tokenIndexFrom, tokenIndexTo, amountIn, 0, _DEADLINE_);
    }

    function _tradeBalancer(TradeRoute memory route, uint256 amountIn)
        internal
    {
        require(route.from == address(0), 'route.from should be zero address');
        _increaseAllowance(route.fromToken, route.routerAddress, amountIn);
        IBalancerRouter(route.routerAddress).swap(
            Balancer.SingleSwap({
                poolId: IBalancerPool(route.lpAddress).getPoolId(),
                kind: Balancer.SwapKind.GIVEN_IN,
                assetIn: IAsset(route.fromToken),
                assetOut: IAsset(route.toToken),
                amount: amountIn,
                userData: '0x'
            }),
            Balancer.FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(this),
                toInternalBalance: false
            }),
            0,
            _DEADLINE_
        );
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        UniswapV3CallbackData memory data = abi.decode(
            _data,
            (UniswapV3CallbackData)
        );
        IUniswapV3Pool pool = UniswapV3CallbackValidation.verifyCallback(
            _UNISWAP_V3_FACTORY_,
            data.token0,
            data.token1,
            data.fee
        );
        require(
            address(pool) == msg.sender,
            'UV3Callback: msg.sender is not UniswapV3 Pool'
        );
        if (amount0Delta > 0) {
            IERC20(data.token0).safeTransfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(data.token1).safeTransfer(msg.sender, uint256(amount1Delta));
        }
    }

    /*

    █▀▀ █▀█ █░░ █░░ █▀▀ █▀▀ ▀█▀   █▀▀ █▀▀ █▀▀
    █▄▄ █▄█ █▄▄ █▄▄ ██▄ █▄▄ ░█░   █▀░ ██▄ ██▄

    */

    function _collectFee(uint256 amount, address token)
        internal
        returns (uint256 remainingAmount)
    {
        uint256 fee = _calculateFee(amount);
        require(fee < amount, 'Fee exceeds amount');
        remainingAmount = amount - fee;
        if (_ETH_ == token) {
            (bool sent, ) = _FEE_WALLET_ADDR_.call{value: fee}('');
            require(sent, 'Failed to send Ether too fee');
        } else {
            IERC20(token).safeTransfer(_FEE_WALLET_ADDR_, fee);
        }
    }

    function _calculateFee(uint256 amount) internal pure returns (uint256 fee) {
        return amount / 1000;
    }

    function _collectStopLimitFee(
        uint256 amount,
        address token,
        uint256 stopLimitFee,
        uint256 minimumStopLimitFee
    ) internal returns (uint256 remainingAmount) {
        uint256 feeAmount = _calculateStopLimitFee(amount, stopLimitFee);
        if (feeAmount < minimumStopLimitFee) {
            feeAmount = minimumStopLimitFee;
        }
        require(feeAmount < amount, 'Fee exceeds amount');
        remainingAmount = amount - feeAmount;
        if (_ETH_ == token) {
            (bool sent, ) = _FEE_WALLET_ADDR_.call{value: feeAmount}('');
            require(sent, 'Failed to send Ether too fee');
        } else {
            IERC20(token).safeTransfer(_FEE_WALLET_ADDR_, feeAmount);
        }
    }

    function _calculateStopLimitFee(uint256 amount, uint256 stopLimitFee)
        internal
        pure
        returns (uint256)
    {
        return (amount * stopLimitFee) / 10000;
    }

    // internal functions

    function _transferFromSender(
        address token,
        address to,
        uint256 amount,
        address srcToken,
        TradeData memory data
    ) internal {
        data.amountIn = data.amountIn - amount;
        if (srcToken != _ETH_) {
            IArkenApprove(_ARKEN_APPROVE_).transferToken(
                address(token),
                msg.sender,
                to,
                amount
            );
        } else {
            _wrapEther(_WETH_, amount);
            if (to != address(this)) {
                IERC20(_WETH_).safeTransfer(to, amount);
            }
        }
    }

    function _wrapEther(address weth, uint256 amount) internal {
        IWETH(weth).deposit{value: amount}();
    }

    function _unwrapEther(address weth, uint256 amount) internal {
        IWETH(weth).withdraw(amount);
    }

    function _increaseAllowance(
        address token,
        address spender,
        uint256 amount
    ) internal {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (amount > allowance) {
            uint256 increaseAmount = MAX_INT - allowance;
            IERC20(token).safeIncreaseAllowance(spender, increaseAmount);
        }
    }

    function _getBalance(address token, address account)
        internal
        view
        returns (uint256)
    {
        if (_ETH_ == token) {
            return account.balance;
        } else {
            return IERC20(token).balanceOf(account);
        }
    }

    /*

    █▀▄ █▀▀ █░█
    █▄▀ ██▄ ▀▄▀

    */
    function testTransfer(TradeDescription memory desc)
        external
        payable
        returns (uint256 returnAmount)
    {
        IERC20 dstToken = IERC20(desc.dstToken);
        TradeData memory data = TradeData({amountIn: desc.amountIn});
        returnAmount = _trade(desc, data);
        uint256 beforeAmount = dstToken.balanceOf(desc.to);
        dstToken.safeTransfer(desc.to, returnAmount);
        uint256 afterAmount = dstToken.balanceOf(desc.to);
        uint256 got = afterAmount - beforeAmount;
        require(got == returnAmount, 'ArkenTester: Has Tax');
    }
}
