// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../libs/Trigonometry.sol";

/**
 * @title StrategicPool
 * @dev A contract for managing a strategic pool of tokens.
 */
contract StrategicPool is Initializable, Ownable {
    bool public initialized = false;
    address public constant BURN_ADDRESS = address(0);
    int256 public totalBurnedAmount = 0; // The total amount of tokens burned from the pool
    int256 public lastBurnedAmount = 0;
    int256 public constant constantValueFromFormula = 1000; // A constant value used in the formula

    event Burned(uint256 amount, bool withFormula); // Event emitted when tokens are burned from the pool
    event Deposit(address indexed sender, uint amount, uint balance); // Event emitted when pool received mtc

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     * It emits a Deposit event to record the deposit details.
     */
    receive() external payable {
        emit Deposit(_msgSender(), msg.value, address(this).balance);
    }

    /**
     * @dev Initializes the contract.
     */
    function initialize() external initializer {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Burns tokens from the pool using a formula.
     * @param currentPrice The current price used in the burn formula
     * @param blocksInTwoMonths The number of blocks in two months used in the burn formula
     */
    function burnWithFormula(
        int256 currentPrice,
        int256 blocksInTwoMonths
    ) external onlyOwner {
        uint256 amount = uint256(
            calculateBurnAmount(currentPrice, blocksInTwoMonths)
        );

        require(amount > 0, "StrategicPool: amount must be bigger than zero");

        totalBurnedAmount += int256(amount);
        lastBurnedAmount = int256(amount);

        (bool sent, ) = BURN_ADDRESS.call{value: amount}("");
        require(sent, "StrategicPool: unable to burn");

        emit Burned(amount, true);
    }

    /**
     * @dev Burns tokens from the pool without using a formula.
     * @param burnAmount The amount of tokens to burn
     */
    function burn(uint256 burnAmount) external onlyOwner {
        totalBurnedAmount += int256(burnAmount);

        (bool sent, ) = BURN_ADDRESS.call{value: burnAmount}("");
        require(sent, "StrategicPool: unable to burn");

        emit Burned(burnAmount, false);
    }

    /**
     * @dev Calculates the amount of tokens to burn using a formula.
     * @param _currentPrice The current price used in the burn formula
     * @param _blocksInTwoMonths The number of blocks in two months used in the burn formula
     * @return The amount of tokens to burn
     */
    function calculateBurnAmount(
        int256 _currentPrice,
        int256 _blocksInTwoMonths
    ) public view returns (int256) {
        return
            (((((_blocksInTwoMonths * (13 * 1e4)) * 1e18) /
                ((100 * _currentPrice) + (constantValueFromFormula * 1e18))) *
                1e18) *
                ((Trigonometry.cos(
                    uint256(
                        (((totalBurnedAmount / 1e9) + (86 * 1e18)) *
                            int256(Trigonometry.PI)) / (180 * 1e18)
                    )
                ) * 2923) / 1e3)) / 1e18;
    }
}
