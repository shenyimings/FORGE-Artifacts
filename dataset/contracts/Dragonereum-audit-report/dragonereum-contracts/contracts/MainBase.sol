pragma solidity 0.4.25;


import "./Common/Pausable.sol";
import "./Common/Upgradable.sol";
import "./Common/HumanOriented.sol";
import "./CoreController.sol";
import "./User.sol";
import "./Events.sol";


contract MainBase is Pausable, Upgradable, HumanOriented {
    CoreController coreController;
    User user;
    Events events;

    function claimEgg(uint8 _dragonType) external onlyHuman whenNotPaused {
        (
            uint256 _eggId,
            uint256 _restAmount,
            uint256 _lastBlock,
            uint256 _interval
        ) = coreController.claimEgg(msg.sender, _dragonType);

        events.emitEggClaimed(msg.sender, _eggId);
        events.emitDistributionUpdated(_restAmount, _lastBlock, _interval);
    }

    // ACTIONS WITH OWN TOKENS

    function sendToNest(
        uint256 _eggId
    ) external onlyHuman whenNotPaused {
        (
            bool _isHatched,
            uint256 _newDragonId,
            uint256 _hatchedId,
            address _owner
        ) = coreController.sendToNest(msg.sender, _eggId);

        events.emitEggSentToNest(msg.sender, _eggId);

        if (_isHatched) {
            events.emitEggHatched(_owner, _newDragonId, _hatchedId);
        }
    }

    function breed(uint256 _momId, uint256 _dadId) external onlyHuman whenNotPaused {
        uint256 eggId = coreController.breed(msg.sender, _momId, _dadId);
        events.emitEggCreated(msg.sender, eggId);
    }

    function upgradeDragonGenes(uint256 _id, uint16[10] _dnaPoints) external onlyHuman whenNotPaused {
        coreController.upgradeDragonGenes(msg.sender, _id, _dnaPoints);
        events.emitDragonUpgraded(_id);
    }

    function setDragonTactics(uint256 _id, uint8 _melee, uint8 _attack) external onlyHuman whenNotPaused {
        coreController.setDragonTactics(msg.sender, _id, _melee, _attack);
        events.emitDragonTacticsSet(_id, _melee, _attack);
    }

    function setDragonName(uint256 _id, string _name) external onlyHuman whenNotPaused returns (bytes32 name) {
        name = coreController.setDragonName(msg.sender, _id, _name);
        events.emitDragonNameSet(_id, name);
    }

    function setDragonSpecialPeacefulSkill(uint256 _id, uint8 _class) external onlyHuman whenNotPaused {
        coreController.setDragonSpecialPeacefulSkill(msg.sender, _id, _class);
        events.emitSkillSet(_id);
    }

    function useDragonSpecialPeacefulSkill(uint256 _id, uint256 _target) external onlyHuman whenNotPaused {
        coreController.useDragonSpecialPeacefulSkill(msg.sender, _id, _target);
        events.emitSkillUsed(_id, _target);
    }

    // LEADERBOARD

    function distributeLeaderboardRewards() external onlyHuman whenNotPaused {
        (
            uint256[10] memory _dragons,
            address[10] memory _users
        ) = coreController.distributeLeaderboardRewards();
        events.emitLeaderboardRewardsDistributed(_dragons, _users);
    }

    // USER

    function setName(string _name) external onlyHuman whenNotPaused returns (bytes32 name) {
        name = user.setName(msg.sender, _name);
        events.emitUserNameSet(msg.sender, name);
    }

    function getName(address _user) external view returns (bytes32) {
        return user.getName(_user);
    }

    // UPDATE CONTRACT

    function setInternalDependencies(address[] _newDependencies) public onlyOwner {
        super.setInternalDependencies(_newDependencies);

        coreController = CoreController(_newDependencies[0]);
        user = User(_newDependencies[1]);
        events = Events(_newDependencies[2]);
    }
}
