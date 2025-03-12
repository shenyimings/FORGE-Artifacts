// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "./Dependencies/Ownable.sol";
import "./Dependencies/SafeMath.sol";
import "./Dependencies/IERC20.sol";
import "./Interfaces/ILUSDToken.sol";
import "./Interfaces/IMultiRewards.sol";


interface IERC3156FlashBorrower {

    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}


contract FlashLender is Ownable {

    using SafeMath for uint256;

    uint256 public constant feePct = 9;  // 1 = 0.0001%
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    address public lqtyStaking;
    mapping (address => address) lendSources;

    constructor() public Ownable() {}

    function setAddresses(address _lqtyStaking) external onlyOwner {
        require(lqtyStaking == address(0));
        lqtyStaking = _lqtyStaking;
    }

    function setLendSources(address[] calldata tokens, address[] calldata lenders) external onlyOwner {
        require(tokens.length == lenders.length);
        for (uint i = 0; i < tokens.length; i++) {
            lendSources[tokens[i]] = lenders[i];
        }
    }

    /**
     * @dev The amount of currency available to be lent.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(
        address token
    ) external view returns (uint256) {
        address source = lendSources[token];
        if (source == address(0)) return 0;
        if (source == token) return 2**128-1;
        return IERC20(token).balanceOf(source);
    }

    function _flashFee(uint256 amount) internal pure returns (uint256) {
        return amount.mul(feePct).div(10000);
    }

    /**
     * @dev The fee to be charged for a given loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(
        address token,
        uint256 amount
    ) external view returns (uint256) {
        require(lendSources[token] != address(0), "FlashLender: Unsupported currency");
        return _flashFee(amount);
    }

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        address pool = lendSources[token];
        require(pool != address(0), "FlashLender: Unsupported currency");
        uint256 fee = _flashFee(amount);

        if (pool == token) {
            require(amount < 2**128);
            ILUSDToken(token).mint(address(receiver), amount);
        } else {
            require(
                IERC20(token).transferFrom(pool, address(receiver), amount),
                "FlashLender: Transfer failed"
            );
        }

        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
            "FlashLender: Callback failed"
        );

        if (pool == token) {
            ILUSDToken(token).burn(address(receiver), amount);
        } else {
            require(
                IERC20(token).transferFrom(address(receiver), pool, amount),
                "FlashLender: Repay Principal failed"
            );
        }

        require(
            IERC20(token).transferFrom(address(receiver), lqtyStaking, fee),
            "FlashLender: Repay Fee failed"
        );
        IMultiRewards(lqtyStaking).notifyRewardAmount(token, fee);

        return true;
    }
}
