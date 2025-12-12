// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./EnumerableSet.sol";

contract MultiSig {
    using EnumerableSet for EnumerableSet.UintSet;

    address[] public owners;
    uint256 public threshold;

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        mapping(address => bool) confirmedBy;
    }

    Proposal[] public proposals;

    EnumerableSet.UintSet private _undoneProposals;

    mapping(address => bool) public isOwner;

    event Received(address sender, uint256 amount);

    event ProposalCreated(
        uint256 proposalId,
        address target,
        uint256 value,
        bytes data
    );

    event ProposalConfirmed(uint256 proposalId, address confirmer);

    event ProposalExecuted(uint256 proposalId);

    event ProposalExecutionLog(
        uint256 proposalId,
        address target,
        uint256 value,
        bytes data,
        bool success
    );

    modifier onlyOwner() {
        require(isOwner[msg.sender], "The caller is not the owner");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposals.length, "Proposal does not exist");
        _;
    }

    modifier notExecuted(uint256 proposalId) {
        require(!proposals[proposalId].executed, "Proposal already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "At least one owner required");

        require(
            _threshold > 0 && _threshold <= _owners.length,
            "Invalid threshold"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "Invalid owner address");
            require(!isOwner[owner], "Duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function submitProposal(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyOwner {
        // Get Proposal ID
        uint256 proposalId = proposals.length;
        Proposal storage proposal = proposals.push();
        proposal.target = target;
        proposal.value = value;
        proposal.data = data;
        proposal.executed = false;
        proposal.confirmations = 0;

        _undoneProposals.add(proposalId);

        emit ProposalCreated(proposalId, target, value, data);
    }

    function confirmProposal(
        uint256 proposalId
    ) external onlyOwner proposalExists(proposalId) notExecuted(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(
            !proposal.confirmedBy[msg.sender],
            "Proposal already confirmed by sender"
        );

        proposal.confirmedBy[msg.sender] = true;
        proposal.confirmations++;

        emit ProposalConfirmed(proposalId, msg.sender);

        if (proposal.confirmations >= threshold) {
            executeProposal(proposalId);
        }
    }

    function executeProposal(
        uint256 proposalId
    ) internal proposalExists(proposalId) notExecuted(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(
            proposal.confirmations >= threshold,
            "Insufficient confirmations"
        );

        proposal.executed = true;

        (bool success, ) = proposal.target.call{value: proposal.value}(
            proposal.data
        );

        emit ProposalExecutionLog(
            proposalId,
            proposal.target,
            proposal.value,
            proposal.data,
            success
        );

        require(success, "Execution failed");

        _undoneProposals.remove(proposalId);

        emit ProposalExecuted(proposalId);
    }

    function getProposalsLength() public view returns (uint256) {
        return proposals.length;
    }

    function isConfirmed(
        uint256 proposalId,
        address owner
    ) external view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.confirmedBy[owner];
    }

    function getProposal(
        uint256 proposalId
    ) external view returns (address, uint256, bytes memory, bool, uint256) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.target,
            proposal.value,
            proposal.data,
            proposal.executed,
            proposal.confirmations
        );
    }

    function unDoneProposals() public view returns (uint256[] memory) {
        uint256 len = _undoneProposals.length();
        uint256[] memory ret = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            ret[i] = _undoneProposals.at(i);
        }
        return ret;
    }
}
