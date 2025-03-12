pragma solidity 0.5.12;

interface IDTokenController {
    function getdToken(address _token) external view returns (address);
}
