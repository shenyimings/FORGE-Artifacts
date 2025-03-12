pragma solidity 0.8.9;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICurveFi_2} from "../../interfaces/ICurve.sol";
import {NeuronPoolBaseInitialize} from "../NeuronPoolBaseInitialize.sol";
import {IUniswapRouterV2} from "../../interfaces/IUniswapRouterV2.sol";

contract NeuronPoolCurveDoublePoolExtends is NeuronPoolBaseInitialize {
    using SafeERC20 for IERC20Metadata;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IUniswapRouterV2 public constant UNISWAP_ROUTER = IUniswapRouterV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    ICurveFi_2 internal basePool;
    IERC20Metadata internal firstTokenInBasePool;
    IERC20Metadata internal secondTokenInBasePool;

    function initialize(
        address _token,
        address _governance,
        address _timelock,
        address _controller,
        address _basePool,
        address _firstTokenInBasePool,
        address _secondTokenInBasePool
    ) external initializer {
        __NeuronPoolBaseInitialize_init(_token, _governance, _timelock, _controller);
        basePool = ICurveFi_2(_basePool);
        firstTokenInBasePool = IERC20Metadata(_firstTokenInBasePool);
        secondTokenInBasePool = IERC20Metadata(_secondTokenInBasePool);
    }

    function getSupportedTokens() external view override returns (address[] memory tokens) {
        tokens = new address[](4);
        tokens[0] = address(token);
        tokens[1] = address(firstTokenInBasePool);
        tokens[2] = address(secondTokenInBasePool);
        tokens[3] = address(USDC);
    }

    function deposit(address _enterToken, uint256 _amount) public payable override returns (uint256) {
        require(_amount > 0, "!_amount");

        address self = address(this);
        IERC20Metadata enterToken = IERC20Metadata(_enterToken);
        IERC20Metadata _token = token;

        uint256 _balance = balance();

        if (enterToken == _token) {
            _token.safeTransferFrom(msg.sender, self, _amount);
        } else if (enterToken == USDC) {
            _amount = depositBaseToken(secondTokenInBasePool, _swapUSDCtoSecondToken(_amount));
        } else {
            enterToken.safeTransferFrom(msg.sender, self, _amount);
            _amount = depositBaseToken(enterToken, _amount);
        }

        return _mintShares(_amount, _balance);
    }

    function depositBaseToken(IERC20Metadata _enterToken, uint256 _amount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata _token = token;
        IERC20Metadata enterToken = IERC20Metadata(_enterToken);
        ICurveFi_2 _basePool = basePool;

        uint256[2] memory addLiquidityPayload;
        if (enterToken == firstTokenInBasePool) {
            addLiquidityPayload[0] = _amount;
        } else if (enterToken == secondTokenInBasePool) {
            addLiquidityPayload[1] = _amount;
        } else {
            revert("!token");
        }

        enterToken.approve(address(_basePool), _amount);

        uint256 initialLpTokenBalance = _token.balanceOf(self);

        _basePool.add_liquidity(addLiquidityPayload, 0);

        uint256 resultLpTokenBalance = _token.balanceOf(self);

        require(resultLpTokenBalance > initialLpTokenBalance, "Tokens were not received from the liquidity pool");

        return resultLpTokenBalance - initialLpTokenBalance;
    }

    function withdraw(address _withdrawableToken, uint256 _shares) public override {
        uint256 amount = _withdrawLpTokens(_shares);
        IERC20Metadata withdrawableToken = IERC20Metadata(_withdrawableToken);

        if (withdrawableToken != token) {
            if (withdrawableToken == USDC) {
                amount = _swapSecondTokentoUSDC(withdrawBaseToken(address(secondTokenInBasePool), amount));
            } else {
                amount = withdrawBaseToken(address(_withdrawableToken), amount);
            }
        }

        require(amount > 0, "!withdrawableAmount");

        withdrawableToken.safeTransfer(msg.sender, amount);
    }

    function withdrawBaseToken(address _withdrawableToken, uint256 _userLpTokensAmount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata withdrawableToken = IERC20Metadata(_withdrawableToken);

        int128 tokenIndex;
        if (withdrawableToken == firstTokenInBasePool) {
            tokenIndex = 0;
        } else if (withdrawableToken == secondTokenInBasePool) {
            tokenIndex = 1;
        } else {
            revert("!token");
        }

        uint256 initialLpTokenBalance = withdrawableToken.balanceOf(self);
        basePool.remove_liquidity_one_coin(_userLpTokensAmount, tokenIndex, 0);
        uint256 resultLpTokenBalance = withdrawableToken.balanceOf(self);

        require(resultLpTokenBalance > initialLpTokenBalance, "!base_amount");

        return resultLpTokenBalance - initialLpTokenBalance;
    }

    function _swapUSDCtoSecondToken(uint256 _amount) internal returns (uint256) {
        address self = address(this);
        USDC.transferFrom(msg.sender, self, _amount);
        
        IERC20Metadata _secondTokenInBasePool = secondTokenInBasePool;
        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = WETH;
        path[2] = address(_secondTokenInBasePool);
        USDC.approve(address(UNISWAP_ROUTER), _amount);

        uint256 initialBalance = _secondTokenInBasePool.balanceOf(self);
        UNISWAP_ROUTER.swapExactTokensForTokens(_amount, 0, path, self, block.timestamp + 60);
        uint256 resultBalance = _secondTokenInBasePool.balanceOf(self);

        require(resultBalance > initialBalance, "!Second token balance");

        return resultBalance - initialBalance;
    }

    function _swapSecondTokentoUSDC(uint256 _amount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata _secondTokenInBasePool = secondTokenInBasePool;

        address[] memory path = new address[](3);
        path[0] = address(_secondTokenInBasePool);
        path[1] = WETH;
        path[2] = address(USDC);
        _secondTokenInBasePool.approve(address(UNISWAP_ROUTER), _amount);

        uint256 initialBalance = USDC.balanceOf(self);
        UNISWAP_ROUTER.swapExactTokensForTokens(_amount, 0, path, self, block.timestamp + 60);
        uint256 resultBalance = USDC.balanceOf(self);

        require(resultBalance > initialBalance, "!USDC balance");

        return resultBalance - initialBalance;
    }
}
