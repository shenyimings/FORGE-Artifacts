pragma solidity 0.8.9;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICurveFi_3_int128} from "../../interfaces/ICurve.sol";
import {NeuronPoolBase} from "../NeuronPoolBase.sol";
import {IUniswapRouterV2} from "../../interfaces/IUniswapRouterV2.sol";

contract NeuronPoolCurveSBTC is NeuronPoolBase {
    using SafeERC20 for IERC20Metadata;

    ICurveFi_3_int128 internal constant BASE_POOL = ICurveFi_3_int128(0x7fC77b5c7614E1533320Ea6DDc2Eb61fa00A9714);

    IERC20Metadata internal constant RENBTC = IERC20Metadata(0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D);
    IERC20Metadata internal constant WBTC = IERC20Metadata(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Metadata internal constant SBTC = IERC20Metadata(0xfE18be6b3Bd88A2D2A7f928d00292E7a9963CfC6);

    IUniswapRouterV2 public constant UNISWAP_ROUTER = IUniswapRouterV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(
        address _token,
        address _governance,
        address _timelock,
        address _controller
    ) NeuronPoolBase(_token, _governance, _timelock, _controller) {}

    function getSupportedTokens() external view override returns (address[] memory tokens) {
        tokens = new address[](5);
        tokens[0] = address(token);
        tokens[1] = address(RENBTC);
        tokens[2] = address(WBTC);
        tokens[3] = address(SBTC);
        tokens[4] = address(USDC);
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
            (IERC20Metadata premiumToken, uint256 amount) = _swapUSDCtoToken(_amount);
            _amount = depositBaseToken(premiumToken, amount);
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

        uint256[3] memory addLiquidityPayload;
        if (enterToken == RENBTC) {
            addLiquidityPayload[0] = _amount;
        } else if (enterToken == WBTC) {
            addLiquidityPayload[1] = _amount;
        } else if (enterToken == SBTC) {
            addLiquidityPayload[2] = _amount;
        } else {
            revert("!token");
        }

        enterToken.safeApprove(address(BASE_POOL), 0);
        enterToken.safeApprove(address(BASE_POOL), _amount);

        uint256 initialLpTokenBalance = _token.balanceOf(self);

        BASE_POOL.add_liquidity(addLiquidityPayload, 0);

        uint256 resultLpTokenBalance = _token.balanceOf(self);

        require(resultLpTokenBalance > initialLpTokenBalance, "Tokens were not received from the liquidity pool");

        return resultLpTokenBalance - initialLpTokenBalance;
    }

    function withdraw(address _withdrawableToken, uint256 _shares) public override {
        uint256 amount = _withdrawLpTokens(_shares);

        IERC20Metadata withdrawableToken = IERC20Metadata(_withdrawableToken);

        if (withdrawableToken != token) {
            if (withdrawableToken == USDC) {
                amount = _swapTokentoUSDC(withdrawBaseToken(getMostPremium(), amount));
            } else {
                amount = withdrawBaseToken(address(_withdrawableToken), amount);
            }
        }

        require(amount > 0, "!amount");

        withdrawableToken.safeTransfer(msg.sender, amount);
    }

    function withdrawBaseToken(address _withdrawableToken, uint256 _userLpTokensAmount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata withdrawableToken = IERC20Metadata(_withdrawableToken);

        int128 tokenIndex;
        if (withdrawableToken == RENBTC) {
            tokenIndex = 0;
        } else if (withdrawableToken == WBTC) {
            tokenIndex = 1;
        } else if (withdrawableToken == SBTC) {
            tokenIndex = 2;
        } else {
            revert("!token");
        }

        uint256 initialLpTokenBalance = withdrawableToken.balanceOf(self);
        BASE_POOL.remove_liquidity_one_coin(_userLpTokensAmount, tokenIndex, 0);
        uint256 resultLpTokenBalance = withdrawableToken.balanceOf(self);

        require(resultLpTokenBalance > initialLpTokenBalance, "!base_amount");

        return resultLpTokenBalance - initialLpTokenBalance;
    }

    function _swapUSDCtoToken(uint256 _amount) internal returns (IERC20Metadata, uint256) {
        address self = address(this);
        USDC.transferFrom(msg.sender, self, _amount);

        IERC20Metadata premiumToken = IERC20Metadata(getMostPremium());
        address[] memory path = new address[](3);
        path[0] = address(USDC);
        path[1] = WETH;
        path[2] = address(premiumToken);
        USDC.approve(address(UNISWAP_ROUTER), _amount);

        uint256 initialBalance = premiumToken.balanceOf(self);
        UNISWAP_ROUTER.swapExactTokensForTokens(_amount, 0, path, self, block.timestamp + 60);
        uint256 resultBalance = premiumToken.balanceOf(self);

        require(resultBalance > initialBalance, "!Second token balance");

        return (premiumToken, resultBalance - initialBalance);
    }

    function _swapTokentoUSDC(uint256 _amount) internal returns (uint256) {

        address self = address(this);
        IERC20Metadata _token = IERC20Metadata(getMostPremium());

        address[] memory path = new address[](3);
        path[0] = address(_token);
        path[1] = WETH;
        path[2] = address(USDC);
        _token.approve(address(UNISWAP_ROUTER), _amount);

        uint256 initialBalance = USDC.balanceOf(self);
        UNISWAP_ROUTER.swapExactTokensForTokens(_amount, 0, path, self, block.timestamp + 60);
        uint256 resultBalance = USDC.balanceOf(self);

        require(resultBalance > initialBalance, "!USDC balance");

        return resultBalance - initialBalance;
    }

    function getMostPremium() internal view returns (address) {
        uint256[3] memory balances = [
            BASE_POOL.balances(0) * 1e10,
            BASE_POOL.balances(1) * 1e10,
            BASE_POOL.balances(2)
        ];

        if (balances[0] < balances[1] && balances[0] < balances[2]) {
            return address(RENBTC);
        }
        if (balances[1] < balances[0] && balances[1] < balances[2]) {
            return address(WBTC);
        }
        return address(SBTC);
    }
}
