pragma solidity ^0.6.12;
// SPDX-License-Identifier: Unlicensed

interface IERC20 {

        function totalSupply() external view returns (uint256);

        /**
         * @dev Returns the amount of tokens owned by `account`.
         */
        function balanceOf(address account) external view returns (uint256);

        /**
         * @dev Moves `amount` tokens from the caller's account to `recipient`.
         *
         * Returns a boolean value indicating whether the operation succeeded.
         *
         * Emits a {Transfer} event.
         */
        function transfer(address recipient, uint256 amount) external returns (bool);

        /**
         * @dev Returns the remaining number of tokens that `spender` will be
         * allowed to spend on behalf of `owner` through {transferFrom}. This is
         * zero by default.
         *
         * This value changes when {approve} or {transferFrom} are called.
         */
        function allowance(address owner, address spender) external view returns (uint256);

        /**
         * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
         *
         * Returns a boolean value indicating whether the operation succeeded.
         *
         * IMPORTANT: Beware that changing an allowance with this method brings the risk
         * that someone may use both the old and the new allowance by unfortunate
         * transaction ordering. One possible solution to mitigate this race
         * condition is to first reduce the spender's allowance to 0 and set the
         * desired value afterwards:
         * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
         *
         * Emits an {Approval} event.
         */
        function approve(address spender, uint256 amount) external returns (bool);

        /**
         * @dev Moves `amount` tokens from `sender` to `recipient` using the
         * allowance mechanism. `amount` is then deducted from the caller's
         * allowance.
         *
         * Returns a boolean value indicating whether the operation succeeded.
         *
         * Emits a {Transfer} event.
         */
        function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

        /**
         * @dev Emitted when `value` tokens are moved from one account (`from`) to
         * another (`to`).
         *
         * Note that `value` may be zero.
         */
        event Transfer(address indexed from, address indexed to, uint256 value);

        /**
         * @dev Emitted when the allowance of a `spender` for an `owner` is set by
         * a call to {approve}. `value` is the new allowance.
         */
        event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Context {
        function _msgSender() internal view virtual returns (address payable) {
                return msg.sender;
        }

        function _msgData() internal view virtual returns (bytes memory) {
                this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
                return msg.data;
        }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
        address private _owner;
        address private _previousOwner;
        uint256 private _lockTime;

        event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

        /**
         * @dev Initializes the contract setting the deployer as the initial owner.
         */
        constructor () internal {
                address msgSender = _msgSender();
                _owner = msgSender;
                emit OwnershipTransferred(address(0), msgSender);
        }

        /**
         * @dev Returns the address of the current owner.
         */
        function owner() public view returns (address) {
                return _owner;
        }

        /**
         * @dev Throws if called by any account other than the owner.
         */
        modifier onlyOwner() {
                require(_owner == _msgSender(), "Ownable: caller is not the owner");
                _;
        }

         /**
         * @dev Leaves the contract without owner. It will not be possible to call
         * `onlyOwner` functions anymore. Can only be called by the current owner.
         *
         * NOTE: Renouncing ownership will leave the contract without an owner,
         * thereby removing any functionality that is only available to the owner.
         */
        function renounceOwnership() public virtual onlyOwner {
                emit OwnershipTransferred(_owner, address(0));
                _owner = address(0);
        }

        /**
         * @dev Transfers ownership of the contract to a new account (`newOwner`).
         * Can only be called by the current owner.
         */
        function transferOwnership(address newOwner) public virtual onlyOwner {
                require(newOwner != address(0), "Ownable: new owner is the zero address");
                emit OwnershipTransferred(_owner, newOwner);
                _owner = newOwner;
        }

        function geUnlockTime() public view returns (uint256) {
                return _lockTime;
        }

        //Locks the contract for owner for the amount of time provided
        function lock(uint256 time) public virtual onlyOwner {
                _previousOwner = _owner;
                _owner = address(0);
                _lockTime = now + time;
                emit OwnershipTransferred(_owner, address(0));
        }
        
        //Unlocks the contract for owner when _lockTime is exceeds
        function unlock() public virtual {
                require(_previousOwner == msg.sender, "You don't have permission to unlock");
                require(now > _lockTime , "Contract is locked until 7 days");
                emit OwnershipTransferred(_owner, _previousOwner);
                _owner = _previousOwner;
        }
}

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
 
library SafeMath {
        /**
         * @dev Returns the addition of two unsigned integers, reverting on
         * overflow.
         *
         * Counterpart to Solidity's `+` operator.
         *
         * Requirements:
         *
         * - Addition cannot overflow.
         */
        function add(uint256 a, uint256 b) internal pure returns (uint256) {
                uint256 c = a + b;
                require(c >= a, "SafeMath: addition overflow");

                return c;
        }

        /**
         * @dev Returns the subtraction of two unsigned integers, reverting on
         * overflow (when the result is negative).
         *
         * Counterpart to Solidity's `-` operator.
         *
         * Requirements:
         *
         * - Subtraction cannot overflow.
         */
        function sub(uint256 a, uint256 b) internal pure returns (uint256) {
                return sub(a, b, "SafeMath: subtraction overflow");
        }

        /**
         * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
         * overflow (when the result is negative).
         *
         * Counterpart to Solidity's `-` operator.
         *
         * Requirements:
         *
         * - Subtraction cannot overflow.
         */
        function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
                require(b <= a, errorMessage);
                uint256 c = a - b;

                return c;
        }

        /**
         * @dev Returns the multiplication of two unsigned integers, reverting on
         * overflow.
         *
         * Counterpart to Solidity's `*` operator.
         *
         * Requirements:
         *
         * - Multiplication cannot overflow.
         */
        function mul(uint256 a, uint256 b) internal pure returns (uint256) {
                // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
                // benefit is lost if 'b' is also tested.
                // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
                if (a == 0) {
                        return 0;
                }

                uint256 c = a * b;
                require(c / a == b, "SafeMath: multiplication overflow");

                return c;
        }

        /**
         * @dev Returns the integer division of two unsigned integers. Reverts on
         * division by zero. The result is rounded towards zero.
         *
         * Counterpart to Solidity's `/` operator. Note: this function uses a
         * `revert` opcode (which leaves remaining gas untouched) while Solidity
         * uses an invalid opcode to revert (consuming all remaining gas).
         *
         * Requirements:
         *
         * - The divisor cannot be zero.
         */
        function div(uint256 a, uint256 b) internal pure returns (uint256) {
                return div(a, b, "SafeMath: division by zero");
        }

        /**
         * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
         * division by zero. The result is rounded towards zero.
         *
         * Counterpart to Solidity's `/` operator. Note: this function uses a
         * `revert` opcode (which leaves remaining gas untouched) while Solidity
         * uses an invalid opcode to revert (consuming all remaining gas).
         *
         * Requirements:
         *
         * - The divisor cannot be zero.
         */
        function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
                require(b > 0, errorMessage);
                uint256 c = a / b;
                // assert(a == b * c + a % b); // There is no case in which this doesn't hold

                return c;
        }

        /**
         * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
         * Reverts when dividing by zero.
         *
         * Counterpart to Solidity's `%` operator. This function uses a `revert`
         * opcode (which leaves remaining gas untouched) while Solidity uses an
         * invalid opcode to revert (consuming all remaining gas).
         *
         * Requirements:
         *
         * - The divisor cannot be zero.
         */
        function mod(uint256 a, uint256 b) internal pure returns (uint256) {
                return mod(a, b, "SafeMath: modulo by zero");
        }

        /**
         * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
         * Reverts with custom message when dividing by zero.
         *
         * Counterpart to Solidity's `%` operator. This function uses a `revert`
         * opcode (which leaves remaining gas untouched) while Solidity uses an
         * invalid opcode to revert (consuming all remaining gas).
         *
         * Requirements:
         *
         * - The divisor cannot be zero.
         */
        function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
                require(b != 0, errorMessage);
                return a % b;
        }
}

contract TokenVault is Ownable {
    IERC20 public token;
    uint256 private constant MAX = ~uint256(0);

    constructor (IERC20 _token) public {
        token = _token;
        token.approve(address(msg.sender), MAX);
    }
}

contract FEEDVesting is Ownable {
    using SafeMath for uint256;

    IERC20 public token;
    mapping (uint256 => Grant) public tokenGrants;
    uint256 public constant oneMonth = 30 days;
    uint256 public totalVestingCount;

    struct Grant {
        uint256 startTime;
        uint256 amount;
        uint256 vestingDuration;
        uint256 vestingCliff;
        uint256 monthsClaimed;
        uint256 totalClaimed;
        address recipient;
        address vault;
    }

    event GrantAdded(address indexed recipient, address vault, uint256 vestingId);
    event GrantTokensClaimed(address indexed recipient, uint256 amountClaimed);

    constructor (IERC20 _token) public {
        token = _token;
    }
    
    function addTokenGrant(
        address _recipient,
        uint256 _startDelayInMonths,
        uint256 _amount,
        uint256 _vestingDurationInMonths,
        uint256 _vestingCliffInMonths
    ) external onlyOwner
    {        
        uint256 amountVestedPerMonth = _amount.div(_vestingDurationInMonths);
        require(amountVestedPerMonth > 0, "amount vested per month should be more than 0");

        TokenVault _vault = new TokenVault(token);

        // Transfer the grant tokens under the control of the vesting contract's vault
        require(token.transferFrom(owner(), address(_vault), _amount), "token transfer failed");

        Grant memory grant = Grant({
            startTime: currentTime() + _startDelayInMonths * oneMonth,
            amount: _amount,
            vestingDuration: _vestingDurationInMonths,
            vestingCliff: _vestingCliffInMonths,
            monthsClaimed: 0,
            totalClaimed: 0,
            recipient: _recipient,
            vault: address(_vault)
        });
        tokenGrants[totalVestingCount] = grant;
        emit GrantAdded(_recipient, address(_vault), totalVestingCount);
        totalVestingCount = totalVestingCount + 1;
    }

    function getActiveGrants(address _recipient) public view returns(uint256[] memory) {
        uint256 i = 0;
        uint256[] memory recipientGrants = new uint256[](totalVestingCount);
        uint256 totalActive = 0;
        for(i; i < totalVestingCount; i++) {
            if(tokenGrants[i].recipient == _recipient) {
                recipientGrants[totalActive] = i;
                totalActive++;
            }
        }
        assembly {
            mstore(recipientGrants, totalActive)
        }
        return recipientGrants;
    }

    /// @notice Calculate the vested and unclaimed months and tokens available for `_grantId` to claim
    /// Due to rounding errors once grant duration is reached, returns the entire left grant amount
    /// Returns (0, 0) if cliff has not been reached
    function calculateGrantClaim(uint256 _grantId) public view returns (uint256, uint256) {
        Grant storage tokenGrant = tokenGrants[_grantId];

        // For grants created with a future start date, that hasn't been reached, return 0, 0
        if (currentTime() < tokenGrant.startTime) {
            return (0, 0);
        }

        // Check cliff was reached
        uint elapsedMonths = currentTime().sub(tokenGrant.startTime).div(oneMonth);
        
        if (elapsedMonths < tokenGrant.vestingCliff) {
            return (elapsedMonths, 0);
        }

        // If over vesting duration, all tokens vested
        if (elapsedMonths >= tokenGrant.vestingDuration) {
            uint256 remainingGrant = token.balanceOf(tokenGrant.vault);
            return (tokenGrant.vestingDuration, remainingGrant);
        } else {
            uint256 monthsVested = elapsedMonths.sub(tokenGrant.monthsClaimed);
            uint256 amountVestedPerMonth = tokenGrant.amount.div(uint256(tokenGrant.vestingDuration));
            uint256 amountVested = uint256(monthsVested.mul(amountVestedPerMonth));
            return (monthsVested, amountVested);
        }
    }

    /// @notice Allows a grant recipient to claim their vested tokens. Errors if no tokens have vested
    /// It is advised recipients check they are entitled to claim via `calculateGrantClaim` before calling this
    function claimVestedTokens(uint256 _grantId) external {
        uint256 monthsVested;
        uint256 amountVested;
        (monthsVested, amountVested) = calculateGrantClaim(_grantId);
        require(amountVested > 0, "amount vested is 0");

        Grant storage tokenGrant = tokenGrants[_grantId];
        tokenGrant.monthsClaimed = tokenGrant.monthsClaimed.add(monthsVested);
        tokenGrant.totalClaimed = tokenGrant.totalClaimed.add(amountVested);
        
        require(token.transferFrom(tokenGrant.vault, tokenGrant.recipient, amountVested), "no tokens in vault");
        emit GrantTokensClaimed(tokenGrant.recipient, amountVested);
    }

    function currentTime() public view returns(uint256) {
        return block.timestamp;
    }

    function tokensVestedPerMonth(uint256 _grantId) public view returns(uint256) {
        Grant storage tokenGrant = tokenGrants[_grantId];
        return tokenGrant.amount.div(uint256(tokenGrant.vestingDuration));
    }

    function getGrantInfo(uint256 _grantId) public view returns(uint256, uint256, uint256, uint256, uint256, uint256, address, address) {
        Grant storage tokenGrant = tokenGrants[_grantId];
        return (
            tokenGrant.startTime,
            tokenGrant.amount,
            tokenGrant.vestingDuration,
            tokenGrant.vestingCliff,
            tokenGrant.monthsClaimed,
            tokenGrant.totalClaimed,
            tokenGrant.recipient,
            tokenGrant.vault
            );
    }
}
