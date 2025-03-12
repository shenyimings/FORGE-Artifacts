pragma solidity 0.5.16;

import { ScoringMachine } from "../../../user-rating/contracts/score/ScoringMachine.sol";
import { IRegistry } from "../interfaces/IRegistry.sol";

contract BTokenScore is ScoringMachine {

    IRegistry public registry;
    string private constant parent = "BTokenScore";

    modifier onlyAvatar() {
        address _owner = registry.ownerOf(msg.sender);
        require(_owner != address(0), "Score: not-an-avatar");
        _;
    }

    function setRegistry(address _registry) public onlyOwner {
        require(address(registry) == address(0), "Score: registry-already-set");
        registry = IRegistry(_registry);
    }

    // Create Asset ID
    // ================
    function user(address _user) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent, _user));
    }

    function debtAsset(address cToken) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent, "debt", cToken));
    }

    function collAsset(address cToken) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent, "coll", cToken));
    }

    function slashedAsset(address cToken) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(parent, "slashed-debt", cToken));
    }

    // Update Score
    // =============
    function updateDebtScore(address _user, address cToken, int256 amount) external onlyAvatar {
        updateScore(user(_user), debtAsset(cToken), amount, now);
    }

    function updateCollScore(address _user, address cToken, int256 amount) external onlyAvatar {
        updateScore(user(_user), collAsset(cToken), amount, now);
    }

    function slashedScore(address _user, address cToken, int256 amount) external {
        // TODO implement
        // updateScore(user(_user), slashedAsset(cToken), amount, now);
    }

    // Get Score
    // ==========
    function getDebtScore(address _user, address cToken, uint256 time, uint256 spinStart) public view returns (uint) {
        return getScore(user(_user), debtAsset(cToken), time, spinStart, 0);
    }

    function getDebtGlobalScore(address cToken, uint256 time, uint256 spinStart) public view returns (uint) {
        return getScore(GLOBAL_USER, debtAsset(cToken), time, spinStart, 0);
    }

    function getCollScore(address _user, address cToken, uint256 time, uint256 spinStart) public view returns (uint) {
        return getScore(user(_user), collAsset(cToken), time, spinStart, 0);
    }

    function getCollGlobalScore(address cToken, uint256 time, uint256 spinStart) public view returns (uint) {
        return getScore(GLOBAL_USER, collAsset(cToken), time, spinStart, 0);
    }

    function getSlashedScore(address _user, address cToken, uint256 time, uint256 spinStart) public view returns (uint) {
        return getScore(user(_user), slashedAsset(cToken), time, spinStart, 0);
    }

    function getSlashedGlobalScore(address cToken, uint256 time, uint256 spinStart) public view returns (uint) {
        return getScore(GLOBAL_USER, slashedAsset(cToken), time, spinStart, 0);
    }
}