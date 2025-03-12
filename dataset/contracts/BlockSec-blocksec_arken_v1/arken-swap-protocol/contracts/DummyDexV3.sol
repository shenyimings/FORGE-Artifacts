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

import 'hardhat/console.sol';

contract DummyDexV3 is Ownable {
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



    function dummyTrade(TradeDescription memory desc) external payable {
        require(desc.amountIn > 0, 'Amount-in needs to be more than zero00');
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

        //swap
        if (_ETH_ != desc.srcToken) {
            IERC20(desc.srcToken).safeTransferFrom(msg.sender, address(this), desc.amountIn);
        }
        uint256 returnAmount = desc.amountOutMin + (desc.amountOutMin / 10);

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
}
