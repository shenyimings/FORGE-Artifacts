// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

//////////////////////////////////////////////////////////////////////////////////////
// @title   Peanut Protocol, Authored Escrow Contract (simplified)
// @version 1.0
// @author  H & K
// @dev     This contract is used to send link payments.
// @dev     more at: https://peanut.to
//////////////////////////////////////////////////////////////////////////////////////
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//                         ⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⣶⣦⣌⠙⠋⢡⣴⣶⡄⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⣿⣿⣿⡿⢋⣠⣶⣶⡌⠻⣿⠟⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡆⠸⠟⢁⣴⣿⣿⣿⣿⣿⡦⠉⣴⡇⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⠟⠀⠰⣿⣿⣿⣿⣿⣿⠟⣠⡄⠹⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⢸⡿⢋⣤⣿⣄⠙⣿⣿⡿⠟⣡⣾⣿⣿⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣾⠿⠀⢠⣾⣿⣿⣿⣦⠈⠉⢠⣾⣿⣿⣿⠏⠀⠀⠀
// ⠀⠀⠀⠀⣀⣤⣦⣄⠙⠋⣠⣴⣿⣿⣿⣿⠿⠛⢁⣴⣦⡄⠙⠛⠋⠁⠀⠀⠀⠀
// ⠀⠀⢀⣾⣿⣿⠟⢁⣴⣦⡈⠻⣿⣿⡿⠁⡀⠚⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠘⣿⠟⢁⣴⣿⣿⣿⣿⣦⡈⠛⢁⣼⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⢰⡦⠀⢴⣿⣿⣿⣿⣿⣿⣿⠟⢀⠘⠿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠘⢀⣶⡀⠻⣿⣿⣿⣿⡿⠋⣠⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⢿⣿⣿⣦⡈⠻⣿⠟⢁⣼⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠈⠻⣿⣿⣿⠖⢀⠐⠿⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠈⠉⠁⠀⠀⠀⠀⠀
//
//////////////////////////////////////////////////////////////////////////////////////

// imports
import "@openzeppelin/contracts/access/Ownable.sol";

contract AuthoredEscrow is Ownable {
    struct deposit {
        address sender;
        uint256 amount; // amount to send
        bytes32 pwdHash; // hash of the deposit password
    }
    // technically sender and pwdHash could be optional, optimizing on gas fees

    deposit[] public deposits; // array of deposits
    bool emergency = false; // emergency flag

    // events
    event Deposit(address indexed sender, uint256 amount, uint256 index);
    event Withdraw(address indexed recipient, uint256 amount);

    // constructor
    constructor() {}

    // deposit ether to escrow & get a deposit id
    function makeDeposit(bytes32 pwdHash) external payable returns (uint256) {
        require(msg.value > 0, "deposit must be greater than 0");

        // store new deposit
        deposit memory newDeposit;
        newDeposit.amount = msg.value;
        newDeposit.sender = msg.sender;
        newDeposit.pwdHash = pwdHash;
        deposits.push(newDeposit);
        emit Deposit(msg.sender, msg.value, deposits.length - 1);
        // return id of new deposit
        return deposits.length - 1;
    }

    // sender can always withdraw deposited assets at any time
    function withdrawSender(uint256 _index) external {
        require(_index < deposits.length, "index out of bounds");
        require(deposits[_index].sender == msg.sender, "only sender can withdraw");

        // transfer ether back to sender
        payable(msg.sender).transfer(deposits[_index].amount);
        emit Withdraw(deposits[_index].sender, deposits[_index].amount);

        // remove deposit from array
        delete deposits[_index];
    }

    // centralized transfer function to transfer ether to recipients newly created wallet
    // TODO: replace with zk-SNARK based function
    // TODO: rename AuthoredWithdraw
    function withdrawOwner(uint256 _index, address _recipient, bytes32 _pwd) external onlyOwner {
        require(_index < deposits.length, "index out of bounds");
        // require that the deposits[idx] is not deleted
        require(deposits[_index].sender != address(0), "deposit has already been claimed");
        // require that the password is correct (disable if DB loss)
        if (!emergency) {
            require(keccak256(abi.encodePacked(_pwd)) == deposits[_index].pwdHash, "incorrect password");
        }

        // transfer ether to recipient
        payable(_recipient).transfer(deposits[_index].amount);
        emit Withdraw(_recipient, deposits[_index].amount);

        // remove deposit from array
        delete deposits[_index];
    }

    //// Some utility functions ////
    function getDepositCount() external view returns (uint256) {
        return deposits.length;
    }

    function getDeposit(uint256 _index) external view returns (deposit memory) {
        return deposits[_index];
    }

    function getDepositsSent(address _sender) external view returns (deposit[] memory) {
        deposit[] memory depositsSent = new deposit[](deposits.length);
        uint256 count = 0;
        for (uint256 i = 0; i < deposits.length; i++) {
            if (deposits[i].sender == _sender) {
                depositsSent[count] = deposits[i];
                count++;
            }
        }
        return depositsSent;
    }

    // and that's all! Have a nutty day!
}
