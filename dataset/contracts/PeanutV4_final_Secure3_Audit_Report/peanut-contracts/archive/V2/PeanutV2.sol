// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

//////////////////////////////////////////////////////////////////////////////////////
// @title   Peanut Protocol
// @dev     This contract is used to send non front-runnable link payments. These can
//          be erc20, erc721, or just plain eth. The recipient address is arbitrary.
// @version 2.0
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
import "@openzeppelin/contracts/access/Ownable.sol"; //
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract PeanutV2 is Ownable {
    struct deposit {
        address tokenAddress; // address of the token being sent. 0x0 for eth
        uint8 contractType; // 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155
        uint256 amount; // amount of tokens being sent
        uint256 tokenId; // id of the token being sent if erc721 or erc1155
        address sender; // sender can always withdraw (20 bytes)
        bytes32 key; // hash of the deposit password. Could also be asymmetric crypto. (20 bytes)
        address claimer; // inits to 0x0 (20 bytes)
        uint256 unlockUntilBlockNumber; // Block window up until which the deposit is locked (32 bytes)
        uint256 lockCost; // to protect against DoS Attacks(32 bytes)
        bool senderCanWithdraw; // whether the sender can withdraw their own tx (1 byte)
        bool ownerCanWithdraw; // whether this is a trusted sponsored transaction (1 byte)
    } // bytes: 20 + 1 + 32 + 32 + 20 + 32 + 20 + 32 + 32 + 1 + 1 = 223 bytes. Can be optimized.

    deposit[] public deposits; // array of deposits

    // events
    event Deposit(address indexed sender, uint256 amount, uint256 index);
    event Withdraw(address indexed recipient, uint256 amount);

    // constructor
    constructor() public {
        // nothing to do here
    }

    /**
     * @dev Function to make a deposit
     * @param _tokenAddress address of the token being sent. 0x0 for eth
     * @param _contractType uint8 for the type of contract being sent. 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155
     * @param _amount uint256 of the amount of tokens being sent (if erc20)
     * @param _tokenId uint256 of the id of the token being sent if erc721 or erc1155
     * @param _key bytes32 of the hash of the deposit password.
     * @param _lockCost uint256 of the cost in wei to lock the deposit to claimer
     * @param _senderCanWithdraw bool of whether the sender can withdraw the deposit
     * @param _ownerCanWithdraw bool of whether the owner can withdraw the deposit
     * @return uint256 of the index of the deposit
     */
    function makeDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        bytes32 _key,
        uint256 _lockCost,
        bool _senderCanWithdraw,
        bool _ownerCanWithdraw
    ) external payable returns (uint256) {
        // check that the contract type is valid
        require(_contractType < 4, "INVALID CONTRACT TYPE");

        // handle eth deposits
        if (_contractType == 0) {
            // check that the amount sent is equal to the amount being deposited
            require(msg.value > 0, "NO ETH SENT");

            // create the deposit
            deposits.push(
                deposit({
                    tokenAddress: _tokenAddress,
                    contractType: _contractType,
                    amount: msg.value,
                    tokenId: _tokenId,
                    sender: msg.sender,
                    key: _key,
                    claimer: address(0),
                    unlockUntilBlockNumber: 0,
                    lockCost: _lockCost,
                    senderCanWithdraw: _senderCanWithdraw,
                    ownerCanWithdraw: _ownerCanWithdraw
                })
            );
        } else if (_contractType == 1) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function
            // Unfortunately there's no way of doing this in just one transaction.
            // Wallet abstraction pls

            IERC20 token = IERC20(_tokenAddress);

            // require users token balance to be greater than or equal to the amount being deposited
            require(token.balanceOf(msg.sender) >= _amount, "INSUFFICIENT TOKEN BALANCE");

            // require allowance to be at least the amount being deposited
            require(token.allowance(msg.sender, address(this)) >= _amount, "INSUFFICIENT ALLOWANCE");

            // transfer the tokens to the contract
            require(
                token.transferFrom(msg.sender, address(this), _amount), "TRANSFER FAILED. CHECK ALLOWANCE & BALANCE"
            );

            // create the deposit
            deposits.push(
                deposit({
                    tokenAddress: _tokenAddress,
                    contractType: _contractType,
                    amount: _amount,
                    tokenId: _tokenId,
                    sender: msg.sender,
                    key: _key,
                    claimer: address(0),
                    unlockUntilBlockNumber: 0,
                    lockCost: _lockCost,
                    senderCanWithdraw: _senderCanWithdraw,
                    ownerCanWithdraw: _ownerCanWithdraw
                })
            );
        } else if (_contractType == 2) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function.

            IERC721 token = IERC721(_tokenAddress);

            require(token.ownerOf(_tokenId) == msg.sender, "Invalid token id");

            token.transferFrom(msg.sender, address(this), _tokenId);

            // create the deposit
            deposits.push(
                deposit({
                    tokenAddress: _tokenAddress,
                    contractType: _contractType,
                    amount: _amount,
                    tokenId: _tokenId,
                    sender: msg.sender,
                    key: _key,
                    claimer: address(0),
                    unlockUntilBlockNumber: 0,
                    lockCost: _lockCost,
                    senderCanWithdraw: _senderCanWithdraw,
                    ownerCanWithdraw: _ownerCanWithdraw
                })
            );
        } else if (_contractType == 3) {
            IERC1155 token = IERC1155(_tokenAddress);
            token.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");

            // TODO: Support IERC1155Receiver

            // create the deposit
            deposits.push(
                deposit({
                    tokenAddress: _tokenAddress,
                    contractType: _contractType,
                    amount: _amount,
                    tokenId: _tokenId,
                    sender: msg.sender,
                    key: _key,
                    claimer: address(0),
                    unlockUntilBlockNumber: 0,
                    lockCost: _lockCost,
                    senderCanWithdraw: _senderCanWithdraw,
                    ownerCanWithdraw: _ownerCanWithdraw
                })
            );
        }

        // emit the deposit event
        emit Deposit(msg.sender, _amount, deposits.length - 1);

        // return id of new deposit
        return deposits.length - 1;
    }

    // sender can withdraw deposited assets at any time
    function withdrawSender(uint256 _index) external {
        require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
        require(deposits[_index].senderCanWithdraw, "DEPOSIT DOES NOT ALLOW SENDER TO WITHDRAW");
        require(deposits[_index].sender == msg.sender, "MUST BE SENDER TO WITHDRAW");

        // handle eth deposits
        if (deposits[_index].contractType == 0) {
            // send eth to sender
            payable(msg.sender).transfer(deposits[_index].amount);
        } else if (deposits[_index].contractType == 1) {
            IERC20 token = IERC20(deposits[_index].tokenAddress);
            token.transfer(msg.sender, deposits[_index].amount);
        } else if (deposits[_index].contractType == 2) {
            IERC721 token = IERC721(deposits[_index].tokenAddress);
            token.transferFrom(address(this), msg.sender, deposits[_index].tokenId);
        } else if (deposits[_index].contractType == 3) {
            IERC1155 token = IERC1155(deposits[_index].tokenAddress);
            token.safeTransferFrom(address(this), msg.sender, deposits[_index].tokenId, deposits[_index].amount, "");
        }

        // emit the withdraw event
        emit Withdraw(msg.sender, deposits[_index].amount);

        // delete the deposit
        delete deposits[_index];
    }

    // Trustless claim function.

    // 1. claimer lock functionality. Sets the recipient address and opens a 100 block timewindow in which the claimer can withdraw the deposit.
    // Costs some ETH to prevent spamming and DoS attacks. Is later refunded to the sender.
    function openWithdrawWindow(uint256 _depositIdx) public payable {
        require(msg.value >= deposits[_depositIdx].lockCost, "THE SENDER SET A HIGHER LOCK COST THAN PROVIDED");
        require(block.number > deposits[_depositIdx].unlockUntilBlockNumber, "DEPOSIT WINDOW IS STILL OPEN");

        // set the claimer
        deposits[_depositIdx].claimer = msg.sender;

        // set the unlock block number
        deposits[_depositIdx].unlockUntilBlockNumber = block.number + 100;

        // emit the deposit window open event
        // emit DepositWindowOpen(msg.sender, _depositIdx);
    }

    // 2. claimer withdraw functionality. Withdraws the deposit to the recipient address.
    function withdraw(uint256 _index, bytes32 _key, address _recipient) external {
        require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
        require(deposits[_index].claimer == msg.sender, "MUST BE CLAIMER TO WITHDRAW");
        require(block.number < deposits[_index].unlockUntilBlockNumber, "DEPOSIT WINDOW NOT OPEN");
        require(keccak256(abi.encodePacked(_key)) == deposits[_index].key, "KEY DOES NOT MATCH");

        // handle eth deposits
        if (deposits[_index].contractType == 0) {
            // send eth to recipient
            payable(_recipient).transfer(deposits[_index].amount);
        } else if (deposits[_index].contractType == 1) {
            IERC20 token = IERC20(deposits[_index].tokenAddress);
            token.transfer(_recipient, deposits[_index].amount);
        } else if (deposits[_index].contractType == 2) {
            IERC721 token = IERC721(deposits[_index].tokenAddress);
            token.transferFrom(address(this), _recipient, deposits[_index].tokenId);
        } else if (deposits[_index].contractType == 3) {
            IERC1155 token = IERC1155(deposits[_index].tokenAddress);
            token.safeTransferFrom(address(this), _recipient, deposits[_index].tokenId, deposits[_index].amount, "");
        }

        // emit the withdraw event
        emit Withdraw(_recipient, deposits[_index].amount);

        // delete the deposit
        delete deposits[_index];
    }

    // centralized transfer function to transfer ether to recipients newly created wallet
    // Is optional, only works if sender has enabled this
    function withdrawOwner(uint256 _index, address _recipient) external onlyOwner {
        require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
        require(deposits[_index].sender != address(0), "DEPOSIT ALREADY WITHDRAWN");
        require(deposits[_index].ownerCanWithdraw, "DEPOSIT DOES NOT ALLOW OWNER TO WITHDRAW");

        // handle eth deposits
        if (deposits[_index].contractType == 0) {
            // send eth to recipient
            payable(_recipient).transfer(deposits[_index].amount);
        } else if (deposits[_index].contractType == 1) {
            IERC20 token = IERC20(deposits[_index].tokenAddress);
            token.transfer(_recipient, deposits[_index].amount);
        } else if (deposits[_index].contractType == 2) {
            IERC721 token = IERC721(deposits[_index].tokenAddress);
            token.transferFrom(address(this), _recipient, deposits[_index].tokenId);
        } else if (deposits[_index].contractType == 3) {
            IERC1155 token = IERC1155(deposits[_index].tokenAddress);
            token.safeTransferFrom(address(this), _recipient, deposits[_index].tokenId, deposits[_index].amount, "");
        }

        // emit the withdraw event
        emit Withdraw(_recipient, deposits[_index].amount);

        // delete the deposit
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
