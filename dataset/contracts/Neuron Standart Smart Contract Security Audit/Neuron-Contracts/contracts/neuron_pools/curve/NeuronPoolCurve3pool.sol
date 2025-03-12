pragma solidity 0.8.9;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICurveFi_3} from "../../interfaces/ICurve.sol";
import {NeuronPoolBase} from "../NeuronPoolBase.sol";

contract NeuronPoolCurve3pool is NeuronPoolBase {
    using SafeERC20 for IERC20Metadata;

    ICurveFi_3 internal constant BASE_POOL = ICurveFi_3(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    IERC20Metadata internal constant DAI = IERC20Metadata(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20Metadata internal constant USDT = IERC20Metadata(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    constructor(
        address _token,
        address _governance,
        address _timelock,
        address _controller
    ) NeuronPoolBase(_token, _governance, _timelock, _controller) {}

    function getSupportedTokens() external view override returns (address[] memory tokens) {
        tokens = new address[](4);
        tokens[0] = address(token);
        tokens[1] = address(DAI);
        tokens[2] = address(USDC);
        tokens[3] = address(USDT);
    }

    function deposit(address _enterToken, uint256 _amount) public payable override returns (uint256) {
        require(_amount > 0, "!_amount");

        address self = address(this);
        IERC20Metadata enterToken = IERC20Metadata(_enterToken);
        IERC20Metadata _token = token;

        uint256 _balance = balance();

        if (enterToken == _token) {
            _token.safeTransferFrom(msg.sender, self, _amount);
        } else {
            _amount = depositBaseToken(enterToken, _amount);
        }

        return _mintShares(_amount, _balance);
    }

    function depositBaseToken(IERC20Metadata _enterToken, uint256 _amount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata _token = token;
        IERC20Metadata enterToken = IERC20Metadata(_enterToken);

        uint256[3] memory addLiquidityPayload;
        if (enterToken == DAI) {
            addLiquidityPayload[0] = _amount;
        } else if (enterToken == USDC) {
            addLiquidityPayload[1] = _amount;
        } else if (enterToken == USDT) {
            addLiquidityPayload[2] = _amount;
        } else {
            revert("!token");
        }

        enterToken.safeTransferFrom(msg.sender, self, _amount);
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
            amount = withdrawBaseToken(address(_withdrawableToken), amount);
        }

        require(amount > 0, "!amount");

        withdrawableToken.safeTransfer(msg.sender, amount);
    }

    function withdrawBaseToken(address _withdrawableToken, uint256 _userLpTokensAmount) internal returns (uint256) {
        address self = address(this);
        IERC20Metadata withdrawableToken = IERC20Metadata(_withdrawableToken);

        int128 tokenIndex;
        if (withdrawableToken == DAI) {
            tokenIndex = 0;
        } else if (withdrawableToken == USDC) {
            tokenIndex = 1;
        } else if (withdrawableToken == USDT) {
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
}
