pragma solidity 0.4.24;

// Mock of https://github.com/cardstack/card-protocol-xdai/blob/bridge-utils-contract/smart-contract-xdai/contracts/BridgeUtils.sol
import "../interfaces/IBridgeUtils.sol";

contract BridgeUtilsMock is IBridgeUtils {
    address public safeMock;

    event UpdateToken(address token);
    event SupplierWallet(address owner, address wallet);

    struct Supplier {
        bool registered;
        address safe;
    }

    mapping(address => Supplier) public suppliers;
    mapping(address => address) public safes;

    constructor(address _safeMock) public {
        safeMock = _safeMock;
    }

    function registerSupplier(address ownerAddr) external returns (address) {
        suppliers[ownerAddr].registered = true;
        suppliers[ownerAddr].safe = safeMock;
        safes[safeMock] = ownerAddr;

        emit SupplierWallet(ownerAddr, safeMock);

        return safeMock;
    }

    function isRegistered(address supplierAddr) public view returns (bool) {
        return suppliers[supplierAddr].registered;
    }

    function updateToken(address tokenAddr) external returns (bool) {
        emit UpdateToken(tokenAddr);
        return true;
    }

    function safeForSupplier(address supplierAddr) public view returns (address) {
        require(isRegistered(supplierAddr), "supplier is not registered");
        return suppliers[supplierAddr].safe;
    }
}
