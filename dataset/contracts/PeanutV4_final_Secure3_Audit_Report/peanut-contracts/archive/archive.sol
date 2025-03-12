// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// partial topup/withdraw
// V5
// event TopUpEvent(uint256 indexed _index, uint256 _additionalAmount, address indexed _senderAddress);
// event PartialWithdrawEvent(uint256 indexed _index, uint256 _withdrawAmount, address indexed _recipientAddress);

//
// TODO: include in next release, not tested
// /**
//  * @notice Function to top up a deposit. Adds the additional amount to the deposit.
//  * @dev Requires that the deposit type is either ETH or ERC20.
//  * @param _index uint256 index of the deposit
//  * @param _additionalAmount uint256 additional amount to be added to the deposit
//  */
// function topUpDeposit(uint256 _index, uint256 _additionalAmount) external payable nonReentrant {
//     // check that the deposit exists
//     require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
//     Deposit storage _deposit = deposits[_index];

//     // check that the deposit type is ETH or ERC20
//     require(_deposit.contractType <= 1, "CAN ONLY TOP UP ETH OR ERC20 DEPOSITS");

//     if (_deposit.contractType == 0) {
//         // handle eth deposits
//         require(msg.value == _additionalAmount, "SENT ETH DOES NOT MATCH THE ADDITIONAL AMOUNT");
//         _deposit.amount += msg.value;
//     } else if (_deposit.contractType == 1) {
//         // handle erc20 deposits
//         IERC20 token = IERC20(_deposit.tokenAddress);
//         token.safeTransferFrom(msg.sender, address(this), _additionalAmount);
//         _deposit.amount += _additionalAmount;
//     }

//     // emit a top up event (you should define this event at the top of your contract)
//     emit TopUpEvent(_index, _additionalAmount, msg.sender);
// }

// /**
//  * @notice Function to withdraw a part of a deposit. Reduces the deposit by the withdrawn amount.
//  * @dev Requires that the withdraw amount is less than or equal to the deposit amount.
//  * @param _index uint256 index of the deposit
//  * @param _withdrawAmount uint256 amount to withdraw from the deposit
//  * @param _recipientAddress address of the recipient
//  * @param _recipientAddressHash bytes32 hash of the recipient address (prefixed with "\x19Ethereum Signed Message:\n32")
//  * @param _signature bytes signature of the recipient address (65 bytes)
//  * @return bool true if successful
//  */
// function withdrawPartialDeposit(
//     uint256 _index,
//     uint256 _withdrawAmount,
//     address _recipientAddress,
//     bytes32 _recipientAddressHash,
//     bytes memory _signature
// ) external nonReentrant returns (bool) {
//     // check that the deposit exists and that it isn't already withdrawn
//     require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
//     Deposit memory _deposit = deposits[_index];
//     require(_deposit.amount > 0, "DEPOSIT ALREADY WITHDRAWN");
//     // check that the recipientAddress hashes to the same value as recipientAddressHash
//     require(
//         _recipientAddressHash == ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(_recipientAddress))),
//         "HASHES DO NOT MATCH"
//     );
//     // check that the signer is the same as the one stored in the deposit
//     address depositSigner = getSigner(_recipientAddressHash, _signature);
//     require(depositSigner == _deposit.pubKey20, "WRONG SIGNATURE");

//     // check that the withdraw amount is less than or equal to the deposit amount
//     require(_deposit.amount >= _withdrawAmount, "WITHDRAW AMOUNT IS GREATER THAN DEPOSIT AMOUNT");

//     // subtract the withdraw amount from the deposit amount
//     _deposit.amount -= _withdrawAmount;

//     // All the existing withdrawal logic, replacing _deposit.amount with _withdrawAmount...

//     // Deposit request is valid. Withdraw the deposit to the recipient address.
//     if (_deposit.contractType == 0) {
//         /// handle eth deposits
//         payable(_recipientAddress).transfer(_withdrawAmount);
//     } else if (_deposit.contractType == 1) {
//         /// handle erc20 deposits
//         IERC20 token = IERC20(_deposit.tokenAddress);
//         token.safeTransfer(_recipientAddress, _withdrawAmount);
//     } else if (_deposit.contractType == 2) {
//         /// handle erc721 deposits
//         IERC721 token = IERC721(_deposit.tokenAddress);
//         token.safeTransferFrom(address(this), _recipientAddress, _deposit.tokenId);
//     } else if (_deposit.contractType == 3) {
//         /// handle erc1155 deposits
//         IERC1155 token = IERC1155(_deposit.tokenAddress);
//         token.safeTransferFrom(address(this), _recipientAddress, _deposit.tokenId, _withdrawAmount, "");
//     } else if (_deposit.contractType == 4) {
//         /// handle rebasing erc20 deposits
//         IECO token = IECO(_deposit.tokenAddress);
//         uint256 scaledAmount = _withdrawAmount / token.getPastLinearInflation(block.number);
//         require(token.transfer(_recipientAddress, scaledAmount), "TRANSFER FAILED");
//     }

//     return true;
// }

/////////////////////
// erc1155 batch received

// /**
//  * @notice Erc1155 token receiver function
//  * @dev These functions are called by the token contracts when a set of tokens is sent to this contract
//  * @dev If calldata is "Internal transfer" then the token was sent by this contract and we don't need to do anything
//  * @param _operator address operator requesting the transfer
//  * @param _from address address which previously owned the token
//  * @param _ids uint256[] IDs of each token being transferred (order and length must match _values array)
//  * @param _values uint256[] amount of each token being transferred (order and length must match _ids array)
//  * @param _data bytes data forwarded from the caller
//  * @dev _data needs to contain array of 20 byte pubKey20s (length must match _ids and _values arrays)
//  */
// function onERC1155BatchReceived(
//     address _operator,
//     address _from,
//     uint256[] calldata _ids,
//     uint256[] calldata _values,
//     bytes calldata _data
// ) external override returns (bytes4) {
//     if (_operator == address(this)) {
//         // if data is "Internal transfer", nothing to do, return
//         return this.onERC1155BatchReceived.selector;
//     } else if (_data.length != (_ids.length * 32)) {
//         // dont accept if data is not 20 bytes per token
//         revert("INVALID CALLDATA");
//     }

//     for (uint256 i = 0; i < _ids.length; i++) {
//         bytes memory _pubKey20Bytes = new bytes(20);
//         for (uint256 j = 0; j < 20; j++) {
//             _pubKey20Bytes[j] = _data[i * 32 + j];
//         }

//         // create deposit
//         deposits.push(
//             Deposit({
//                 tokenAddress: msg.sender, // token address (not the address of transaction sender)
//                 contractType: 3, // 3 is for ERC1155 (should be uint8)
//                 amount: _values[i], // amount of this token
//                 tokenId: _ids[i], // token id
//                 pubKey20: abi.decode(_pubKey20Bytes, (address)), // convert bytes to address
//                 senderAddress: _from,
//                 timestamp: block.timestamp
//             })
//         );

//         // emit the deposit event
//         emit DepositEvent(
//             deposits.length - 1,
//             3,
//             _values[i], // amount of this token
//             _from
//         );
//     }

//     // return correct bytes4
//     return this.onERC1155BatchReceived.selector;
// }
