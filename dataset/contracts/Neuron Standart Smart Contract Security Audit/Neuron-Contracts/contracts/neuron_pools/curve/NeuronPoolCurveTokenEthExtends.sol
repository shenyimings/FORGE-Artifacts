pragma solidity 0.8.9;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICurveFi_2} from "../../interfaces/ICurve.sol";
import {NeuronPoolBaseInitialize} from "../NeuronPoolBaseInitialize.sol";
import {IUniswapRouterV2} from "../../interfaces/IUniswapRouterV2.sol";
import {IWETH} from "../../interfaces/IWETH.sol";

contract NeuronPoolCurveTokenEthExtends is NeuronPoolBaseInitialize {
    using SafeERC20 for IERC20Metadata;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IUniswapRouterV2 public constant UNISWAP_ROUTER = IUniswapRouterV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    ICurveFi_2 internal basePool;
    IERC20Metadata internal secondTokenInBasePool;

    function initialize(
        address _token,
        address _governance,
        address _timelock,
        address _controller,
        address _basePool,
        address _secondTokenInBasePool
    ) external initializer {
        __NeuronPoolBaseInitialize_init(_token, _governance, _timelock, _controller);
        basePool = ICurveFi_2(_basePool);
        secondTokenInBasePool = IERC20Metadata(_secondTokenInBasePool);
    }

    function getSupportedTokens() external view override returns (address[] memory tokens) {
        tokens = new address[](5);
        tokens[0] = address(token);
        tokens[1] = address(ETH);
        tokens[2] = WETH;
        tokens[3] = address(secondTokenInBasePool);
        tokens[4] = address(USDC);
    }

    function deposit(address _enterToken, uint256 _amount) public payable override returns (uint256) {
        IERC20Metadata enterToken = IERC20Metadata(_enterToken);

        require(_amount > 0, "!_amount");

        if (enterToken == ETH) require(msg.value == _amount, "msg.value != _amount");

        address self = address(this);
        IERC20Metadata _token = token;

        uint256 _balance = balance();

        if (enterToken == _token) {
            _token.safeTransferFrom(msg.sender, self, _amount);
        } else if (enterToken == USDC) {
            _amount = depositBaseToken(ETH, _swapUSDCtoETH(_amount));
        } else {
            if (address(enterToken) == WETH) {
                _unwrapWETH(_amount);
                enterToken = ETH;
            }
            _amount = depositBaseToken(enterToken, _amount);
        }

        return _mintShares(_amount, _balance);
    }

    function _unwrapWETH(uint256 _amount) internal {
        IWETH weth = IWETH(WETH);
        weth.transferFrom(msg.sender, address(this), _amount);
        weth.withdraw(_amount);
    }

    function depositBaseToken(IERC20Metadata _enterToken, uint256 _amount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata _token = token;
        ICurveFi_2 _basePool = basePool;

        uint256[2] memory addLiquidityPayload;

        if (_enterToken == ETH) {
            addLiquidityPayload[0] = _amount;
        } else if (_enterToken == secondTokenInBasePool) {
            addLiquidityPayload[1] = _amount;
            _enterToken.safeTransferFrom(msg.sender, self, _amount);
            _enterToken.safeApprove(address(_basePool), 0);
            _enterToken.safeApprove(address(_basePool), _amount);
        } else {
            revert("!token");
        }

        uint256 initialLpTokenBalance = _token.balanceOf(self);

        _basePool.add_liquidity{value: _enterToken == ETH ? _amount : 0}(addLiquidityPayload, 0);

        uint256 resultLpTokenBalance = _token.balanceOf(self);

        require(resultLpTokenBalance > initialLpTokenBalance, "Tokens were not received from the liquidity pool");

        return resultLpTokenBalance - initialLpTokenBalance;
    }

    function withdraw(address _withdrawableToken, uint256 _shares) public override {
        uint256 amount = _withdrawLpTokens(_shares);
        IERC20Metadata withdrawableToken = IERC20Metadata(_withdrawableToken);

        if (withdrawableToken != token) {
            if (withdrawableToken == USDC) {
                amount = _swapETHtoUSDC(withdrawBaseToken(address(ETH), amount));
            } else if(_withdrawableToken == WETH) {
                amount = withdrawBaseToken(address(ETH), amount);
                IWETH(WETH).deposit{value: amount}();
                withdrawableToken = IERC20Metadata(WETH);
            } else {
                amount = withdrawBaseToken(address(_withdrawableToken), amount);
            }
        }

        require(amount > 0, "!withdrawableAmount");

        if (withdrawableToken == ETH) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Transfer ETH failed");
        } else {
            withdrawableToken.safeTransfer(msg.sender, amount);
        }
    }

    function withdrawBaseToken(address _withdrawableToken, uint256 _userLpTokensAmount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata withdrawableToken = IERC20Metadata(_withdrawableToken);

        int128 tokenIndex;
        if (withdrawableToken == ETH) {
            tokenIndex = 0;

            uint256 initialETHBalance = self.balance;
            basePool.remove_liquidity_one_coin(_userLpTokensAmount, tokenIndex, 0);
            uint256 resultETHBalance = self.balance;

            require(resultETHBalance > initialETHBalance, "!base_amount");

            return resultETHBalance - initialETHBalance;
        } else if (withdrawableToken == secondTokenInBasePool) {
            tokenIndex = 1;

            uint256 initialWithdrawableTokenBalance = withdrawableToken.balanceOf(self);
            basePool.remove_liquidity_one_coin(_userLpTokensAmount, tokenIndex, 0);
            uint256 resultWithdrawableTokenBalance = withdrawableToken.balanceOf(self);

            require(resultWithdrawableTokenBalance > initialWithdrawableTokenBalance, "!base_amount");

            return resultWithdrawableTokenBalance - initialWithdrawableTokenBalance;
        } else {
            revert("!token");
        }
    }

    function _swapUSDCtoETH(uint256 _amount) internal returns (uint256) {
        address self = address(this);
        USDC.transferFrom(msg.sender, self, _amount);
        address[] memory path = new address[](2);
        path[0] = address(USDC);
        path[1] = WETH;
        USDC.approve(address(UNISWAP_ROUTER), _amount);

        uint256 initialBalance = self.balance;
        UNISWAP_ROUTER.swapExactTokensForETH(_amount, 0, path, self, block.timestamp + 60);
        uint256 resultBalance = self.balance;

        require(resultBalance > initialBalance, "!eth balance");

        return resultBalance - initialBalance;
    }

    function _swapETHtoUSDC(uint256 _amount) internal returns (uint256) {
        address self = address(this);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(USDC);

        uint256 intialBalance = USDC.balanceOf(self);
        UNISWAP_ROUTER.swapExactETHForTokens{value: _amount}(0, path, self, block.timestamp + 60);
        uint256 resultBalance = USDC.balanceOf(self);

        require(resultBalance > intialBalance, "!USDC balance");

        return resultBalance - intialBalance;
    }
}
