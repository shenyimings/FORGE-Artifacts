pragma solidity 0.4.19;


contract EthereumClaimsRegistry {

    mapping(address => mapping(address => mapping(bytes32 => bytes32))) public registry;

    event ClaimSet(
        address indexed issuer,
        address indexed subject,
        bytes32 indexed key,
        bytes32 value,
        uint updatedAt);

    event ClaimRemoved(
        address indexed issuer,
        address indexed subject,
        bytes32 indexed key,
        uint removedAt);

    // create or update claims
    function setClaim(address subject, bytes32 key, bytes32 value) external {
        registry[msg.sender][subject][key] = value;
        ClaimSet(msg.sender, subject, key, value, now);
    }

    function setSelfClaim(bytes32 key, bytes32 value) external {
        registry[msg.sender][msg.sender][key] = value;
        ClaimSet(msg.sender, msg.sender, key, value, now);
    }

    function removeClaim(address issuer, address subject, bytes32 key) external {
        require(msg.sender == issuer || msg.sender == subject);
        delete registry[issuer][subject][key];
        ClaimRemoved(msg.sender, subject, key, now);
    }

    function getClaim(address issuer, address subject, bytes32 key) external view returns(bytes32) {
        return registry[issuer][subject][key];
    }
}
