pragma solidity 0.4.25;


import "../Withdrawable.sol";


contract MockWithdrawable is Withdrawable {
    function () public payable { }
}
