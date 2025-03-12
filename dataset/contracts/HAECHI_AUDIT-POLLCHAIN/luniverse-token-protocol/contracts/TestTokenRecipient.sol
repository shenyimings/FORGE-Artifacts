pragma solidity ^0.4.24;

import "./EIP20Standard.sol";

contract TestTokenRecipient {
    bytes public extraData;

    event ReceiveApprovalEvent();

    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData)
    external {
        extraData = _extraData;
        EIP20Standard token = EIP20Standard(_token);
        token.transferFrom(_from, this, _value);
        emit ReceiveApprovalEvent();
    }

    function returnHash(bytes32 _sideTokenId, bytes32 _depositId, uint256 _depositCount, address
        _beneficiary, uint256 _amountMT, uint256 _amountST, bytes32 _transactionHash) external
    returns (bytes32) {
        return keccak256(abi.encodePacked(_depositCount, _sideTokenId, _beneficiary, _amountMT, _amountST));
    }
}
