// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IValidator.sol";
import "../depositary/IUpdatable.sol";

contract DepositaryUpdateValidator is IValidator, Ownable {
    using SafeMath for uint256;

    /// @notice Depositary address.
    address public depositary;

    /// @notice Number of blocks from current.
    uint256 public blockLimit;

    /// @notice An event thats emitted when depositary address updated.
    event DepositaryUpdated(address newDepositary);

    /// @notice An event thats emitted when block limit updated.
    event BlockLimitUpdated(uint256 newBlockLimit);

    /**
     * @param _depositary Depositary address.
     * @param _blockLimit Number of blocks from current.
     */
    constructor(address _depositary, uint256 _blockLimit) public {
        depositary = _depositary;
        blockLimit = _blockLimit;
    }

    /**
     * @notice Update depositary address.
     * @param _depositary New depositary address.
     */
    function changeDepositary(address _depositary) external onlyOwner {
        require(_depositary != address(0), "DepositaryUpdateValidator::changeDepositary: invalid depositary address");

        depositary = _depositary;
        emit DepositaryUpdated(_depositary);
    }

    /**
     * @notice Update block limit.
     * @param _blockLimit New block limit.
     */
    function changeBlockLimit(uint256 _blockLimit) external onlyOwner {
        blockLimit = _blockLimit;
        emit BlockLimitUpdated(_blockLimit);
    }

    function validate() external view override returns (bool) {
        uint256 depositaryUpdatedAt = IUpdatable(depositary).lastUpdateBlockNumber();

        return depositaryUpdatedAt == 0 || block.number.sub(blockLimit) <= depositaryUpdatedAt;
    }
}
