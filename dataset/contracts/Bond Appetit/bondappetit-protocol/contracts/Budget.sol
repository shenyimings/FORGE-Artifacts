// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./utils/OwnablePausable.sol";

contract Budget is OwnablePausable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Expenditure item.
    struct Expenditure {
        address recipient;
        uint256 min;
        uint256 target;
    }

    /// @notice Expenditure item to address.
    mapping(address => Expenditure) public expenditures;

    /// @dev Recipients addresses list.
    EnumerableSet.AddressSet internal recipients;

    /// @dev Withdrawal balance of recipients.
    mapping(address => uint256) internal balances;

    /// @notice Total withdrawal balance.
    uint256 public totalSupply;

    /// @notice An event emitted when expenditure item changed.
    event ExpenditureChanged(address recipient, uint256 min, uint256 target);

    /// @notice An event emitted when expenditure item payed.
    event Payed(address recipient, uint256 amount);

    receive() external payable {}

    /**
     * @notice Change expenditure item.
     * @param recipient Recipient address.
     * @param min Minimal balance for payment.
     * @param target Target balance.
     */
    function changeExpenditure(
        address recipient,
        uint256 min,
        uint256 target
    ) external onlyOwner {
        require(min <= target, "Budget::changeExpenditure: minimal balance should be less or equal target balance");

        expenditures[recipient] = Expenditure(recipient, min, target);
        if (target > 0) {
            recipients.add(recipient);
        } else {
            recipients.remove(recipient);
        }
        emit ExpenditureChanged(recipient, min, target);
    }

    /**
     * @notice Get withdrawal balance of recipient.
     */
    function balanceOf(address recipient) public view returns (uint256) {
        return balances[recipient];
    }

    /**
     * @notice Transfer ETH to recipient.
     * @param recipient Recipient.
     * @param amount Transfer amount.
     */
    function transferETH(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance.sub(totalSupply) >= amount, "Budget::transferETH: transfer amount exceeds balance");

        recipient.transfer(amount);
    }

    /**
     * @notice Return all recipients addresses.
     * @return Recipients addresses.
     */
    function getRecipients() external view returns (address[] memory) {
        address[] memory result = new address[](recipients.length());

        for (uint256 i = 0; i < recipients.length(); i++) {
            result[i] = recipients.at(i);
        }

        return result;
    }

    /**
     * @notice Return balance deficit of recipient.
     * @param recipient Target recipient.
     * @return Balance deficit of recipient.
     */
    function deficitTo(address recipient) public view returns (uint256) {
        require(recipients.contains(recipient), "Budget::deficitTo: recipient not in expenditure item");

        uint256 availableBalance = recipient.balance.add(balanceOf(recipient));
        if (availableBalance > expenditures[recipient].min) return 0;

        return expenditures[recipient].target.sub(availableBalance);
    }

    /**
     * @notice Return summary balance deficit of all recipients.
     * @return Summary balance deficit of all recipients.
     */
    function deficit() public view returns (uint256) {
        uint256 result;

        for (uint256 i = 0; i < recipients.length(); i++) {
            result = result.add(deficitTo(recipients.at(i)));
        }

        return result;
    }

    /**
     * @notice Pay ETH to all recipients with balance deficit.
     */
    function pay() external {
        for (uint256 i = 0; i < recipients.length(); i++) {
            uint256 budgetBalance = address(this).balance.sub(totalSupply);
            address recipient = recipients.at(i);
            uint256 amount = deficitTo(recipient);
            if (amount == 0 || budgetBalance < amount) continue;

            balances[recipient] = balanceOf(recipient).add(amount);
            totalSupply = totalSupply.add(amount);
        }
    }

    /**
     * @notice Withdraw ETH to recipient.
     */
    function withdraw() external {
        address payable recipient = _msgSender();
        uint256 amount = balanceOf(recipient);
        require(amount > 0, "Budget::withdraw: transfer amount exceeds balance");

        balances[recipient] = 0;
        totalSupply = totalSupply.sub(amount);
        recipient.transfer(amount);
        emit Payed(recipient, amount);
    }
}
