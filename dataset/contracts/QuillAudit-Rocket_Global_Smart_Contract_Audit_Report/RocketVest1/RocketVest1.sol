// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
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
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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


pragma solidity 0.8.6;

contract RocketVest1 {

    IERC20 private _token;
    address[] private _beneficiaryList;

    struct Beneficiary {
        uint balance;
        uint taken;
        uint start;
        uint releaseTime;
    }

    mapping(address => Beneficiary) private _beneficiaries;

    event Withdrawal(address indexed beneficiary, uint amount);

    constructor(
        address token,
        address[] memory beneficiaries, 
        uint[] memory balances,
        uint [] memory starts,
        uint [] memory releases
        ) {
        
        _token = IERC20(token);

        for(uint i; i < beneficiaries.length; i++) {
            _beneficiaries[beneficiaries[i]] = 
            Beneficiary({
                balance: balances[i],
                taken: 0, 
                start: block.timestamp + starts[i],
                releaseTime: block.timestamp + starts[i] + releases[i]
            });
            _beneficiaryList.push(
                beneficiaries[i]
            );
        }
    }

    function listBeneficiaries(
        ) external view returns(
            address[] memory beneficiary_list
        ) {
        
        return _beneficiaryList;
    }

    function walletBalance(
        address beneficiary
        ) external view returns(
            uint token_balance
        ) {
        
        uint balance = _beneficiaries[beneficiary].balance;
        uint taken = _beneficiaries[beneficiary].taken;
        return balance - taken;
    }

    function walletStartDate(
        address beneficiary
        ) external view returns(
            uint seconds_left
        ) {
        
        uint start = _beneficiaries[beneficiary].start;
        if (start > block.timestamp) return start - block.timestamp;
        else return 0;
    }

    function walletEndDate(
        address beneficiary
        ) external view returns(
            uint seconds_left
        ) {
        
        uint release = _beneficiaries[beneficiary].releaseTime;
        if (release > block.timestamp) return release - block.timestamp;
        else return 0;
    }
     
    function availableToWithdraw(
        address beneficiary
        ) external view returns(
            uint token_released
        ) {
        
        return _released(beneficiary);
    } 

    function tokenAddress(
        ) external view returns(
            address token_address
        ) {
        
        return address(_token);
    }

    function withdrawAvailable(
        address beneficiary
        ) external returns(
            bool success
        ) {
        
        uint released = _released(beneficiary);
        require(
            released > 0, 
            "You do not have any balance available"
        );
        
        _beneficiaries[beneficiary].taken += released;
        require(
            _token.transfer(beneficiary, released), 
            "Error in sending token"
        );
        
        if (_beneficiaries[beneficiary].releaseTime <= block.timestamp) {
            _beneficiaries[beneficiary].balance = 0;
            _beneficiaries[beneficiary].taken = 0;
        }
        emit Withdrawal(beneficiary, released);
        return true; 
    }

    function _released(
        address beneficiary
        ) internal view returns(uint) {

        uint start = _beneficiaries[beneficiary].start;
        uint release = _beneficiaries[beneficiary].releaseTime;
        uint balance = _beneficiaries[beneficiary].balance;
        uint taken = _beneficiaries[beneficiary].taken;
        uint releasedPct;
        
        if (block.timestamp <=  start) return 0;

        if (block.timestamp >= release) releasedPct = 100;
        else releasedPct = ((block.timestamp - start) * 100000) / ((release - start) * 1000);
        
        uint released = (balance * releasedPct) / 100;
        return released - taken;
    }
}