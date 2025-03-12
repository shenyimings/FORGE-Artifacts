pragma solidity ^0.5.12;

import { DSAuth } from "ds-auth/auth.sol";

interface OSMLike {
    function peep() external view returns (bytes32, bool);
    function hop()  external view returns(uint16);
    function zzz()  external view returns(uint64);
}

interface PipLike {
    function read() external view returns (bytes32);
}

contract BudConnector is DSAuth {

    mapping(address => bool) public authorized;
    OSMLike public osm;
    mapping(bytes32 => PipLike) pips;

    constructor(OSMLike osm_) public {
        osm = osm_;
    }

    function authorize(address addr) external auth {
        authorized[addr] = true;
    }

    function setPip(address pip, bytes32 ilk) external auth {
        require(pips[ilk] == PipLike(0), "ilk-already-init");
        pips[ilk] = PipLike(pip);
    }

    function peep() external view returns (bytes32, bool) {
        require(authorized[msg.sender], "!authorized");
        return osm.peep();
    }

    function read(bytes32 ilk) external view returns (bytes32) {
        require(authorized[msg.sender], "!authorized");
        return pips[ilk].read();
    }

    function hop() external view returns(uint16) {
        return osm.hop();
    }

    function zzz() external view returns(uint64) {
        return osm.zzz();
    }
}
