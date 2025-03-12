pragma solidity 0.4.25;

import '../Rise.sol';


contract RiseMock is Rise {
    uint256 currentTime;

    constructor(address _mintSaver, address _cashContract) public Rise(_mintSaver, _cashContract) {}

    function getCurrentTime() public view returns (uint256) {
        if (currentTime == 0) {
            return 3600;
        } else {
            return currentTime;
        }
    }

    function setCurrentTime(uint256 _currentTime) public {
        currentTime = _currentTime;
    }

    function createBlockMock(uint256 _expectedBlockNumber, uint256 _growthRate)
        public
        returns (bool _isSuccess)
    {
        return _createBlock(_expectedBlockNumber, _growthRate);
    }

    function burnQuarantinedMock() public returns (uint256) {
        return _burnQuarantined();
    }

    function zeroeQuarantineMock() public {
        return _burn(address(this), balanceOf(address(this)));
    }
}
