pragma solidity 0.8.9;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {NeuronPoolBase} from "../NeuronPoolBase.sol";
import {IUniswapRouterV2} from "../../interfaces/IUniswapRouterV2.sol";

contract NeuronPoolStabilityPoolLUSD is NeuronPoolBase {
    using SafeERC20 for IERC20Metadata;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IUniswapRouterV2 public constant UNISWAP_ROUTER = IUniswapRouterV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    constructor(
        address _token,
        address _governance,
        address _timelock,
        address _controller
    ) NeuronPoolBase(_token, _governance, _timelock, _controller) {}

    function getSupportedTokens() external view override returns (address[] memory tokens) {
        tokens = new address[](2);
        tokens[0] = address(token);
        tokens[1] = address(USDC);
    }

    function deposit(address _enterToken, uint256 _amount) public payable override returns (uint256) {
        require(_amount > 0, "!_amount");

        address self = address(this);
        IERC20Metadata enterToken = IERC20Metadata(_enterToken);
        IERC20Metadata _token = token;

        uint256 _balance = balance();

        if (enterToken == USDC) {
            _amount = _swapUSDCtoLUSD(_amount);
        } else if (enterToken == _token) {
            _token.safeTransferFrom(msg.sender, self, _amount);
        } else {
            require(false, "!token");
        }

        return _mintShares(_amount, _balance);
    }

    function withdraw(address _withdrawableToken, uint256 _shares) public override {
        uint256 amount = _withdrawLpTokens(_shares);
        IERC20Metadata withdrawableToken = IERC20Metadata(_withdrawableToken);
        IERC20Metadata lusd = IERC20Metadata(token);

        if (withdrawableToken == USDC) {
            amount = _swapLUSDtoUSDC(amount);
        } else if (withdrawableToken != lusd) {
            require(false, "!token");
        }

        require(amount > 0, "!withdrawableAmount");

        withdrawableToken.safeTransfer(msg.sender, amount);
    }

    function _swapUSDCtoLUSD(uint256 _amount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata lusd = IERC20Metadata(token);
        USDC.transferFrom(msg.sender, self, _amount);

        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = WETH;
        path[2] = address(lusd);
        USDC.approve(address(UNISWAP_ROUTER), _amount);

        uint256 initialBalance = lusd.balanceOf(self);
        UNISWAP_ROUTER.swapExactTokensForTokens(_amount, 0, path, self, block.timestamp + 60);
        uint256 resultBalance = lusd.balanceOf(self);

        require(resultBalance > initialBalance, "!LUSD balance");

        return resultBalance - initialBalance;
    }

    function _swapLUSDtoUSDC(uint256 _amount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata lusd = IERC20Metadata(token);

        address[] memory path = new address[](3);
        path[0] = address(lusd);
        path[1] = WETH;
        path[2] = address(USDC);
        lusd.approve(address(UNISWAP_ROUTER), _amount);

        uint256 initialBalance = USDC.balanceOf(self);
        UNISWAP_ROUTER.swapExactTokensForTokens(_amount, 0, path, self, block.timestamp + 60);
        uint256 resultBalance = USDC.balanceOf(self);

        require(resultBalance > initialBalance, "!USDC balance");

        return resultBalance - initialBalance;
    }
}
