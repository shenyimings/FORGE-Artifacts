pragma solidity =0.5.17;

import "./AnonymousTree.sol";
import "./Ownable.sol";

interface IOwnable {
    function transferOwnership(address newOwner) external;
}

contract Deploy is Ownable {
    address VERIFIER;
    uint32 MERKLE_TREE_HEIGHT;
    address HASHER;

    event Created(address, address);

    constructor(
        address _verifier,
        uint32 _merkleTreeHeight,
        address _hasher
    ) public {
        VERIFIER = _verifier;
        MERKLE_TREE_HEIGHT = _merkleTreeHeight;
        HASHER = _hasher;
    }

    function create() public onlyOwner returns (address) {
        address _newAnonymousTree =
            address(new AnonymousTree(VERIFIER, MERKLE_TREE_HEIGHT, HASHER));

        emit Created(owner(), _newAnonymousTree);
    }

    function updateAnonymousTreeOwnership(address _anonymousTree, address _v)
        public
        onlyOwner
    {
        IOwnable(_anonymousTree).transferOwnership(_v);
    }
}
