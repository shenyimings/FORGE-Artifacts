pragma solidity 0.5.16;

contract FlashLoanStub {
    function borrow(address /*_token*/, uint256 _amount, bytes calldata _data) external {
        uint balanceBefore = address(this).balance;
        (bool succ, bytes memory res) = msg.sender.call.value(_amount)("");
        require(succ, "eth-transfer-failed");
        (succ, res) = msg.sender.call(_data);
        require(succ, string(res));
        require(address(this).balance >= balanceBefore, "flash-loan-didnt-repay");
    }

    function deposit() external payable {
        // do nothing
    }

    function() external payable {}
}