// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Aspida's ActionControl module
 * @author Aspida engineer
 * @dev This contract manages the limits and thresholds for actions such as submitting and withdrawing.
 */
abstract contract ActionControl {
    enum Action {
        submit,
        withdraw
    }

    struct ActionData {
        uint256 limit; // The maximum amount allowed for an action
        uint256 threshold; // The minimum amount required for an action
        uint256 latestIndex; // The latest index of the action
        uint256 accumulated; // The accumulated amount of the action
    }

    /**
     * @dev This mapping stores the action data for each action.
     * The key is the Action enum value, and the value is an ActionData struct.
     */
    mapping(Action => ActionData) internal actionDatas_;

    /**
     * @dev Emitted when the "limit" of "actionId" changes.
     */
    event SetActionLimit(Action actionId, uint256 limit);
    /**
     * @dev Emitted when the "threshold" of "actionId" changes.
     */

    event SetActionThreshold(Action actionId, uint256 threshold);
    /**
     * @dev Emitted when the "index" and "accumulated" of "actionId" are updated.
     */

    event UpdateActionData(Action actionId, uint256 index, uint256 accumulated);

    /**
     * @dev Sets the limit for an action
     * @param _actionId The ID of the action
     * @param _limit The maximum amount allowed for the action
     */
    function _setActionLimitInternal(Action _actionId, uint256 _limit) internal {
        ActionData storage _actionData = actionDatas_[_actionId];
        require(_limit != _actionData.limit, "_setActionLimitInternal: Cannot set the same value");

        _actionData.limit = _limit;
        emit SetActionLimit(_actionId, _limit);
    }

    /**
     * @dev Sets the threshold for an action
     * @param _actionId The ID of the action
     * @param _threshold The minimum amount required for the action
     */
    function _setActionThresholdInternal(Action _actionId, uint256 _threshold) internal {
        ActionData storage _actionData = actionDatas_[_actionId];
        require(_threshold != _actionData.threshold, "_setActionThresholdInternal: Cannot set the same value");

        _actionData.threshold = _threshold;
        emit SetActionThreshold(_actionId, _threshold);
    }

    /**
     * @dev Checks if the limit for an action has been exceeded
     * @param _actionData The action data
     * @param _actionId The ID of the action
     * @param _index The index of the action
     * @param _increase The increase in the action
     * @param _accumulated The accumulated amount of the action
     */
    function _checkActionLimit(
        ActionData storage _actionData,
        Action _actionId,
        uint256 _index,
        uint256 _increase,
        uint256 _accumulated
    ) internal {
        if (_actionData.limit > 0) {
            uint256 _accumulatedPerIndex;
            if (_index == _actionData.latestIndex) _accumulatedPerIndex = _accumulated - _actionData.accumulated;

            if (_index != _actionData.latestIndex) {
                _actionData.latestIndex = _index;
                _actionData.accumulated = _accumulated;
                emit UpdateActionData(_actionId, _index, _accumulated);
            }

            require(_accumulatedPerIndex + _increase <= _actionData.limit, "_checkActionLimit: Limit exceeded");
        }
    }

    /**
     * @dev Checks if the limit for an action has been exceeded
     * @param _actionId The ID of the action
     * @param _index The index of the action
     * @param _increase The increase in the action
     * @param _accumulated The accumulated amount of the action
     */
    function _checkActionLimit(Action _actionId, uint256 _index, uint256 _increase, uint256 _accumulated) internal {
        _checkActionLimit(actionDatas_[_actionId], _actionId, _index, _increase, _accumulated);
    }

    /**
     * @dev Checks if the threshold for an action has been met
     * @param _actionData The action data
     * @param _amount The amount to check against the threshold
     */
    function _checkActionThreshold(ActionData storage _actionData, uint256 _amount) internal view {
        require(_amount >= _actionData.threshold, "_checkActionThreshold: Amount exceeds threshold");
    }

    /**
     * @dev Checks if the threshold for an action has been met
     * @param _actionId The ID of the action
     * @param _amount The amount to check against the threshold
     */
    function _checkActionThreshold(Action _actionId, uint256 _amount) internal view {
        _checkActionThreshold(actionDatas_[_actionId], _amount);
    }

    /**
     * @dev Checks if an action has been exceeded or met its threshold
     * @param _actionId The ID of the action
     * @param _index The index of the action
     * @param _increase The increase in the action
     * @param _accumulated The accumulated amount of the action
     */
    function _checkAction(Action _actionId, uint256 _index, uint256 _increase, uint256 _accumulated) internal {
        ActionData storage _actionData = actionDatas_[_actionId];
        _checkActionLimit(_actionData, _actionId, _index, _increase, _accumulated);
        _checkActionThreshold(_actionData, _increase);
    }

    /**
     * @dev Returns the action data for an action
     * @param _actionId The ID of the action
     */
    function actionData(Action _actionId) external view returns (ActionData memory) {
        return actionDatas_[_actionId];
    }

    /**
     * @dev Returns the remaining amount for an action
     * @param _actionId The ID of the action
     */
    function actionRemaining(Action _actionId, uint256 _index, uint256 _accumulated) public view returns (uint256) {
        ActionData storage _actionData = actionDatas_[_actionId];
        if (_actionData.limit > 0) {
            if (_index != _actionData.latestIndex) return _actionData.limit;
            uint256 _indexAccumulated = _accumulated - _actionData.accumulated;
            return _actionData.limit > _indexAccumulated ? _actionData.limit - _indexAccumulated : 0;
        }
        return type(uint256).max;
    }
}
