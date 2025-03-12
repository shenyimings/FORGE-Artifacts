// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../helpers/RolesHandler.sol";
import "../interfaces/IMinerFormulas.sol";
import "../interfaces/IMinerList.sol";

/**
 * @title RewardsPool
 * @notice Holds tokens for miners to claim.
 * @dev A contract for distributing tokens over a specified period of
 * time for mining purposes.
 */
contract RewardsPool is Initializable, RolesHandler {
    /// @notice MinerFormulas instance address
    IMinerFormulas public minerFormulas;
    /// @notice a mapping that holds claimed amounts for each participant
    mapping(address => uint256) public claimedAmounts;

    /// @notice Event emitted when a beneficiary has claimed tokens
    event HasClaimed(address indexed beneficiary, uint256 amount);
    /// @notice Event emitted when pool received mtc
    event Deposit(address indexed sender, uint amount, uint balance);

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     * It emits a Deposit event to record the deposit details.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev Initializes the contract with the specified parameters.
     * @param minerFormulasAddress Address of MinerFormulas contract.
     */
    function initialize(address minerFormulasAddress) external initializer {
        require(
            minerFormulasAddress != address(0),
            "RewardsPool: cannot set zero address"
        );
        minerFormulas = IMinerFormulas(minerFormulasAddress);
    }

    /**
     * @dev Claim tokens for the sender.
     * @return A boolean indicating whether the claim was successful.
     */
    function claim(
        address receiver
    ) external onlyManagerRole(msg.sender) returns (uint256) {
        uint256 amount = calculateClaimableAmount();

        claimedAmounts[receiver] += amount;

        (bool sent, ) = receiver.call{value: amount}("");
        require(sent, "RewardsPool: Unable to claim");

        emit HasClaimed(receiver, amount);

        return amount;
    }

    /**
     * @dev Calculates the amount of tokens claimable for the current period.
     * @return The amount of tokens claimable for the current period.
     */
    function calculateClaimableAmount() public view returns (uint256) {
        return minerFormulas.calculateMetaminerReward();
    }
}
