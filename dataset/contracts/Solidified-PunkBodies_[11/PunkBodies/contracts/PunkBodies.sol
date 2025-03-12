// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "./ERC721Permit.sol";

contract PunkBodies is ERC721Permit {
    address public distributor;

    uint256 max_supply = 10000;

    bytes32 public IMAGE_PROOF = 0x19878c179d9ba9d606b6ab12526e35c5e8982006ca448de546369683ea749de4;
    bytes32 public METADATA_PROOF = 0x72d874dd2aeab34bee4acb929c4edd3715b912cc57eb284458dbb0e7c5e880ed;

    constructor(string memory _baseURI) ERC721Permit("PunkBodies") ERC721("PunkBodies", "PB") {
        _setBaseURI(_baseURI);
    }

    function setDistributor(address _distributor) external {
        require(distributor == address(0), "PunkBodies: distributor already set");
        distributor = _distributor;
    }

    function mint(address to, uint256 tokenId) external {
        require(msg.sender == distributor, "PunkBodies: not authorized.");
        require(tokenId < max_supply, "PunkBodies: max supply reached");
        _mint(to, tokenId);
    }
}
