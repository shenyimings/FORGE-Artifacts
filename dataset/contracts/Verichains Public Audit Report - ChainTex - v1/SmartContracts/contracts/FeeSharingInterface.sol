pragma solidity 0.4.25;

interface FeeSharingInterface {
    function handleFees(address wallet) external payable returns(bool);
}
