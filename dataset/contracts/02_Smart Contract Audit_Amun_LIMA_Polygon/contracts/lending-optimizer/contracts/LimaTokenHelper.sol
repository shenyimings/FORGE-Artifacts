pragma solidity ^0.6.12;

import {
    ERC20PausableUpgradeSafe,
    IERC20,
    SafeMath
} from "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Pausable.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import {AddressArrayUtils} from "./library/AddressArrayUtils.sol";

import {ILimaSwap} from "./interfaces/ILimaSwap.sol";
import {ILimaToken} from "./interfaces/ILimaToken.sol";
import {LimaTokenStorage} from "./LimaTokenStorage.sol";
import {AmunUsers} from "./limaTokenModules/AmunUsers.sol";
import {InvestmentToken} from "./limaTokenModules/InvestmentToken.sol";

/**
 * @title LimaToken
 * @author Lima Protocol
 *
 * Standard LimaToken.
 */
contract LimaTokenHelper is LimaTokenStorage, InvestmentToken, AmunUsers {
    using AddressArrayUtils for address[];
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    function initialize(
        address _limaSwap,
        address _feeWallet,
        address _currentUnderlyingToken,
        address[] memory _underlyingTokens,
        uint256 _mintFee,
        uint256 _burnFee,
        uint256 _performanceFee
    ) public initializer {
        __LimaTokenStorage_init_unchained(
            _limaSwap,
            _feeWallet,
            _currentUnderlyingToken,
            _underlyingTokens,
            _mintFee,
            _burnFee,
            _performanceFee
        );
        __AmunUsers_init_unchained(true);
    }

    /* ============ View ============ */

    /**
     * @dev Get total net token value.
     */
    function getNetTokenValue(address _targetToken)
        public
        view
        returns (uint256 netTokenValue)
    {
        return
            getExpectedReturn(
                currentUnderlyingToken,
                _targetToken,
                getUnderlyingTokenBalance()
            );
    }

    /**
     * @dev Get total net token value.
     */
    function getNetTokenValueOf(address _targetToken, uint256 _amount)
        public
        view
        returns (uint256 netTokenValue)
    {
        return
            getExpectedReturn(
                currentUnderlyingToken,
                _targetToken,
                getUnderlyingTokenBalanceOf(_amount)
            );
    }

    //helper for redirect to LimaSwap
    function getExpectedReturn(
        address _from,
        address _to,
        uint256 _amount
    ) public view returns (uint256 returnAmount) {
        returnAmount = limaSwap.getExpectedReturn(_from, _to, _amount);
    }

    function getUnderlyingTokenBalance() public view returns (uint256 balance) {
        return IERC20(currentUnderlyingToken).balanceOf(limaToken);
    }

    function getUnderlyingTokenBalanceOf(uint256 _amount)
        public
        view
        returns (uint256 balanceOf)
    {
        uint256 balance = getUnderlyingTokenBalance();
        require(balance != 0, "LM4"); //"Balance of underlyng token cant be zero."
        return balance.mul(_amount).div(ILimaToken(limaToken).totalSupply());
    }

    /**
     * @dev Return the performance over the last time interval
     */
    function getPerformanceFee()
        public
        view
        returns (uint256 performanceFeeToWallet)
    {
        performanceFeeToWallet = 0;
        if (
            ILimaToken(limaToken).getUnderlyingTokenBalanceOf(1000 ether) >
            lastUnderlyingBalancePer1000 &&
            performanceFee != 0
        ) {
            performanceFeeToWallet = (
                ILimaToken(limaToken).getUnderlyingTokenBalance().sub(
                    ILimaToken(limaToken)
                        .totalSupply()
                        .mul(lastUnderlyingBalancePer1000)
                        .div(1000 ether)
                )
            )
                .div(performanceFee);
        }
    }

    /* ============ User ============ */

    function getFee(uint256 _amount, uint256 _fee)
        public
        pure
        returns (uint256 feeAmount)
    {
        //get fee
        if (_fee > 0) {
            return _amount.div(_fee);
        }
        return 0;
    }

    /**
     * @dev Gets the expecterd return of a redeem
     */
    function getExpectedReturnRedeem(address _to, uint256 _amount)
        external
        view
        returns (uint256 minimumReturn)
    {
        _amount = getUnderlyingTokenBalanceOf(_amount);

        _amount = _amount.sub(getFee(_amount, burnFee));

        return getExpectedReturn(currentUnderlyingToken, _to, _amount);
    }

    /**
     * @dev Gets the expecterd return of a create
     */
    function getExpectedReturnCreate(address _from, uint256 _amount)
        external
        view
        returns (uint256 minimumReturn)
    {
        _amount = _amount.sub(getFee(_amount, mintFee));
        return getExpectedReturn(_from, currentUnderlyingToken, _amount);
    }

    /**
     * @dev Gets the expected returns of a rebalance
     */
    function getExpectedReturnRebalance(
        address _bestToken
    ) external view returns (uint256 minimumReturnGov) {
        address _govToken = limaSwap.getGovernanceToken(currentUnderlyingToken);
        minimumReturnGov = getExpectedReturn(
            _govToken,
            _bestToken,
            IERC20(_govToken).balanceOf(limaToken)
        );

        return (minimumReturnGov);
    }

    function getGovernanceToken() external view returns (address token) {
        return limaSwap.getGovernanceToken(currentUnderlyingToken);
    }
}
