// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Timers
{
    mapping(bytes32 => uint256) private _deadlines;

    event TimerStarted(bytes32 indexed timer, uint256 deadline);
    event TimerStopped(bytes32 indexed timer);
    event TimerReset(bytes32 indexed timer);

    modifier onlyBeforeTimer(bytes32 id)
    {
        require(_beforeTimer(id), "WithTimers: onlyBeforeTimer");
        _;
    }

    modifier onlyDuringTimer(bytes32 id)
    {
        require(_duringTimer(id), "WithTimers: onlyDuringTimer");
        _;
    }

    modifier onlyAfterTimer(bytes32 id)
    {
        require(_afterTimer(id), "WithTimers: onlyAfterTimer");
        _;
    }

    function _beforeTimer(bytes32 id)
    internal view returns (bool)
    {
        return _deadlines[id] == 0;
    }

    function _duringTimer(bytes32 id)
    internal view returns (bool)
    {
        uint256 deadline = _deadlines[id];
        // solhint-disable-next-line not-rely-on-time
        return deadline != 0 && deadline > block.timestamp;
    }

    function _afterTimer(bytes32 id)
    internal view returns (bool)
    {
        uint256 deadline = _deadlines[id];
        // solhint-disable-next-line not-rely-on-time
        return deadline != 0 && deadline <= block.timestamp;
    }

    function _startTimer(bytes32 id, uint256 delay)
    internal onlyBeforeTimer(id)
    {
        // solhint-disable-next-line not-rely-on-time
        uint256 deadline = block.timestamp + delay;
        _deadlines[id] = deadline;
        emit TimerStarted(id, deadline);
    }

    function _stopTimer(bytes32 id)
    internal onlyDuringTimer(id)
    {
        delete _deadlines[id];
        emit TimerStopped(id);
    }

    function _resetTimer(bytes32 id)
    internal onlyAfterTimer(id)
    {
        delete _deadlines[id];
        emit TimerReset(id);
    }

    function _getDeadline(bytes32 id)
    internal view returns (uint256)
    {
        return _deadlines[id];
    }
}
