pragma solidity 0.4.18;

import "ds-token/token.sol";

contract KeyTokenOwner is DSAuth{

    DSToken public key;

    function KeyTokenOwner(address _key) public
    {
        key = DSToken(_key);
    }

    function stopKeyToken() public auth
    {
        key.stop();
    }

    function startKeyToken() public auth
    {
        key.start();
    }

}
