pragma solidity ^0.5.12;
import { DSAuth } from "ds-auth/auth.sol";

contract VatLike {
    function wards(address a) public view returns(uint);
}

contract ChainLogLike {
     function getAddress(bytes32 _key) public view returns (address addr);
}

contract ChainLogConnector is DSAuth {
    VatLike public vat;
    ChainLogLike public chainLog;
    address public cat;

    constructor(address vat_, address chainLog_) public {
        vat = VatLike(vat_);
        chainLog = ChainLogLike(chainLog_);
    }

    event NewCat(address newCat);
    event NewChainLog(address newChainLog);

    function setCat() public {
        require(vat.wards(cat) == 0, "cat-did-not-change");

        address val;
        (bool catExist,) = address(chainLog).call(abi.encodeWithSignature("getAddress(bytes32)", bytes32("MCD_CAT")));
        if(catExist) val = chainLog.getAddress("MCD_CAT");
        if(! catExist || val == address(0x0)) val = chainLog.getAddress("MCD_DOG");

        require(val != address(0), "zero-val");
        require(vat.wards(val) == 1, "new-cat-is-not-authorized");

        cat = val;

        emit NewCat(val);
    }

    // this does not suppose to happen, but just in case
    function upgradeChainLog() public auth {
        address newChainLog = chainLog.getAddress("CHANGELOG");

        chainLog = ChainLogLike(newChainLog);

        emit NewChainLog(newChainLog);
    }
}
