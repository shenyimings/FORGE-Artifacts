pragma solidity 0.4.24;

interface IBridgeUtils {
    function updateToken(address _tokenAddr) external returns (bool);
    function registerSupplier(address ownerAddr) external returns (address);
    function isRegistered(address supplierAddr) public view returns (bool);
    function safeForSupplier(address supplierAddr) public view returns (address);
}
