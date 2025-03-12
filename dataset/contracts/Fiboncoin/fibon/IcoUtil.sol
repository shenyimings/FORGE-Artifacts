pragma solidity ^0.8.0;

enum IcoStages {
        icoPart1,
        icoPart2,
        icoPart3,
        icoEnd
}

library IcoUtil {
    

    function isFinished(IcoStages stage) internal pure returns (bool) {
        if(stage == IcoStages.icoEnd)
            return true;
        else
            return false;
    }
}