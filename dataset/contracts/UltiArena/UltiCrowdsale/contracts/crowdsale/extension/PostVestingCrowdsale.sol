// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './TimedCrowdsale.sol';

/**
 * @title PostVestingCrowdsale
 * @dev Crowdsale that start tokens vesting after the sale.
 */
abstract contract PostVestingCrowdsale is TimedCrowdsale {
    // Token amount bought by each beneficiary
    mapping(address => uint256) private _balances;
    // Token amount released by each beneficiary
    mapping(address => uint256) private _released;

    // Number of tokens sold
    uint256 private _tokensSold;
    // Number of tokens released
    uint256 private _tokensReleased;

    // Cliff timestamp
    uint256 private _cliff;
    // Vesting start timestamp
    uint256 private _start;
    // Vesting duration in seconds
    uint256 private _duration;
    // Percent of releasable tokens at the vesting start
    uint256 private _initialPercent;

    /**
     * Event for token release logging
     * @param beneficiary who got the tokens
     * @param amount amount of tokens released
     */
    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(
        uint256 startOffset_,
        uint256 cliffDuration_,
        uint256 duration_,
        uint256 initialPercent_
    ) {
        require(cliffDuration_ <= duration_, 'PostVestingCrowdsale: Cliff has to be lower or equal to duration');
        require(initialPercent_ <= 100, 'PostVestingCrowdsale: Initial percent has to be lower than 100%');
        _start = closingTime() + startOffset_;
        _cliff = _start + cliffDuration_;
        _duration = duration_;
        _initialPercent = initialPercent_;
    }

    /**
     * @return timestamp of the start of the vesting process
     */
    function vestingStart() public view returns (uint256) {
        return _start;
    }

    /**
     * @return timestamp of the vesting process cliff
     */
    function vestingCliff() public view returns (uint256) {
        return _cliff;
    }

    /**
     * @return timestamp of the end of the vesting process
     */
    function vestingEnd() public view returns (uint256) {
        return _start + _duration;
    }

    /**
     * @return true if the process of vesting is ended
     */
    function isVestingEnded() public view returns (bool) {
        return block.timestamp >= vestingEnd();
    }

    /**
     * @param beneficiary Tokens beneficiary.
     * @return the number of tokens bought by beneficiary.
     */
    function tokensBought(address beneficiary) public view returns (uint256) {
        return _balances[beneficiary];
    }

    /**
     * @return the number of tokens sold.
     */
    function tokensSold() public view returns (uint256) {
        return _tokensSold;
    }

    /**
     * @return the number of tokens released.
     */
    function tokensReleased() public view returns (uint256) {
        return _tokensReleased;
    }

    /**
     * @param beneficiary Tokens beneficiary.
     * @return the number of tokens that is possible to release by beneficiary.
     */
    function releasableAmount(address beneficiary) public view returns (uint256) {
        return _vestedAmount(beneficiary) - _released[beneficiary];
    }

    /**
     * @dev Releases the token in an amount that is left to withdraw up to the current time.
     * @param beneficiary Tokens beneficiary.
     */
    function _releaseTokens(address beneficiary) internal nonReentrant {
        require(hasClosed(), 'PostVestingCrowdsale: not closed');
        require(
            _balances[beneficiary] - _released[beneficiary] > 0,
            'PostVestingCrowdsale: beneficiary is not due any tokens'
        );
        uint256 amount = releasableAmount(beneficiary);
        require(amount > 0, 'PostVestingCrowdsale: beneficiary tokens are vested');
        _released[beneficiary] = _released[beneficiary] + amount;
        _tokensReleased += amount;
        _deliverTokens(beneficiary, amount);
        emit TokensReleased(beneficiary, amount);
    }

    /**
     * @dev Calculates the vested amount of the token which is the total number of tokens
     * that can be released up to the current time.
     * @param beneficiary Tokens beneficiary.
     * @return the number of vested tokens.
     */
    function _vestedAmount(address beneficiary) internal view returns (uint256) {
        uint256 lastBlockTimestamp = block.timestamp;
        if (block.timestamp < closingTime()) {
            return 0;
        } else if (block.timestamp < _cliff) {
            return (_balances[beneficiary] * _initialPercent) / 100;
        } else if (lastBlockTimestamp >= vestingEnd()) {
            return _balances[beneficiary];
        } else {
            return (_balances[beneficiary] * (lastBlockTimestamp - _start)) / _duration;
        }
    }

    /**
     * @dev Overrides parent by storing due balances and updating total number of sold tokens.
     * @param beneficiary Token beneficiary
     * @param tokenAmount Amount of tokens purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal virtual override {
        _balances[beneficiary] = _balances[beneficiary] + tokenAmount;
        _tokensSold = _tokensSold += tokenAmount;
    }
}
