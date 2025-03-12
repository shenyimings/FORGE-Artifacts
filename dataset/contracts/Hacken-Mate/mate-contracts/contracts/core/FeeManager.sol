// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeManager is Ownable {
    uint256 public constant DENOMINATOR = 10000;

    uint256 public executorFeeNumerator = 15;
    uint256 public feeNumerator = 5;

    address public feeTo;

    event FeeSet(uint256 feeNumerator, uint256 timestamp);
    event ExecutorFeeSet(uint256 executorFeeNumerator, uint256 timestamp);
    event FeeToSet(address feeTo, uint256 timestamp);

    /**
     * @notice Calculates and returns protocol and executor fees
     * @param _amount Amount of tokens in atomic value
     * @return fee Protocol fee
     * @return executorFee Executor fee
     */
    function calculateFees(uint256 _amount)
        public
        view
        returns (uint256 fee, uint256 executorFee)
    {
        fee = (_amount * feeNumerator) / DENOMINATOR;
        executorFee = (_amount * executorFeeNumerator) / DENOMINATOR;
    }

    /**
     * @notice Changes protocol fee
     * @dev Can only be called by owner (governance)
     * @param _feeNumerator Protocol fee numerator
     */
    function setFeeNumerator(uint256 _feeNumerator) external onlyOwner {
        feeNumerator = _feeNumerator;
        emit FeeSet(_feeNumerator, block.timestamp);
    }

    /**
     * @notice Changes executor fee
     * @dev Can only be called by owner (governance)
     * @param _executorFeeNumerator Executor fee numerator
     */
    function setExecutorFeeNumerator(uint256 _executorFeeNumerator)
        external
        onlyOwner
    {
        executorFeeNumerator = _executorFeeNumerator;
        emit ExecutorFeeSet(_executorFeeNumerator, block.timestamp);
    }

    /**
     * @notice Changes an address which should receive protocol fees (MateMaker smart contract)
     * @dev Can only be called by owner (governance)
     * @param _feeTo Address which should receive protocol fees
     */
    function setFeeTo(address _feeTo) external onlyOwner {
        require(_feeTo != address(0), "Invalid fee to address");
        feeTo = _feeTo;
        emit FeeToSet(feeTo, block.timestamp);
    }
}
