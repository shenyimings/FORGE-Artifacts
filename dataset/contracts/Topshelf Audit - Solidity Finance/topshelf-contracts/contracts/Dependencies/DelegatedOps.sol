pragma solidity 0.6.11;

contract DelegatedOps {

    // owner -> caller -> is approved
    mapping(address => mapping(address => bool)) public isApprovedDelegate;

    modifier callerOrDelegated(address _account) {
        require(msg.sender == _account || isApprovedDelegate[_account][msg.sender], "Delegate not approved");
        _;
    }

    function setDelegateApproval(address _delegate, bool _isApproved) external {
        isApprovedDelegate[msg.sender][_delegate] = _isApproved;
    }
}
