pragma solidity ^0.5.12;

import { DSAuth } from "ds-auth/auth.sol";
import { BCdpManager, BCdpScoreLike } from "../BCdpManager.sol";
import { Math } from "../Math.sol";

contract GovernanceExecutor is DSAuth, Math {

    BCdpManager public man;
    address public governance;

    event ScoreUpgraded(address indexed score);
    event PoolUpgraded(address indexed pool);

    constructor(address man_) public {
        man = BCdpManager(man_);
    }

    /**
     * @dev Sets governance address
     * @param governance_ Address of the governance
     */
    function setGovernance(address governance_) external auth {
        require(governance == address(0), "governance-already-set");
        governance = governance_;
    }

    /**
     * @dev Transfer admin of BCdpManager
     * @param owner New admin address
     */
    function doTransferAdmin(address owner) external {
        require(msg.sender == governance, "unauthorized");
        man.setOwner(owner);
    }

    function setPool(address pool) external auth {
        man.setPoolContract(pool);
        emit PoolUpgraded(pool);        
    }

    function setScore(address score) external auth {
        man.setScoreContract(BCdpScoreLike(score));
        emit ScoreUpgraded(score);
    }
}