pragma solidity  0.4.24;

/* taking ideas from FirstBlood token */
contract SafeMath {

    function SafeMath() public {
    }

    function safeAdd(uint256 _x, uint256 _y) pure internal returns(uint256) {
        uint256 z = _x + _y;
        //assert replaced with require *
        require(z >= _x);
        return z;
    }

    function safeSub(uint256 _x, uint256 _y) pure internal returns(uint256) {
        //assert replaced with require *
        require(_x >= _y);
        return _x - _y;
    }

    function safeMul(uint256 _x, uint256 _y) pure internal returns(uint256) {
        uint256 z = _x * _y;
        //assert replaced with require *
        require(_x == 0 || z / _x == _y);
        return z;
    }

}