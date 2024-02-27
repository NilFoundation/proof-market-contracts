// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MonoProofMarketOrderBook is Ownable, AccessControl {

    struct Request {
        uint id;
        uint statementId;
        uint cost;
        address requester;
        uint blockNumber;
    }

    struct Proposal {
        uint id;
        uint statementId;
        uint cost;
        address proposer;
    }

    struct OrderMatch {
        uint requestId;
        uint proposalId;
        uint statementId;
        uint orderCost;
        uint requestCost;
        address requester;
        address proposer;
        uint requestBlockNumber;
        uint matchBlockNumber;
        bool proofed;
    }

    event DataStored(
        uint indexed statementId,
        address indexed requester,
        string data
    );

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(uint => Request[]) public requests;
    mapping(uint => Proposal[]) public proposals;
    mapping(uint => bool) private supportedStatementIds;

    // matching
    OrderMatch[] public orderMatches;
    mapping(address => uint[]) public pendingRequests;
    mapping(address => uint[]) public pendingProposals;

    constructor() Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    modifier statementIdSupported(uint _statementId) {
        require(supportedStatementIds[_statementId], "Statement not supported");
        _;
    }

    function addAdmin(address _admin) public onlyOwner {
        grantRole(ADMIN_ROLE, _admin);
    }

    function removeAdmin(address _admin) public onlyOwner {
        revokeRole(ADMIN_ROLE, _admin);
    }

    function addStatementId(uint _statementId) public onlyRole(ADMIN_ROLE) {
        require(!supportedStatementIds[_statementId], "StatementId already supported");
        supportedStatementIds[_statementId] = true;
    }

    function removeStatementId(uint _statementId) public onlyRole(ADMIN_ROLE) {
        require(supportedStatementIds[_statementId], "StatementId not supported");
        supportedStatementIds[_statementId] = false;
    }

    function submitRequest(uint _statementId, uint _cost) public statementIdSupported(_statementId) {
        Request memory request = Request({
            id: _generateUniqueId(_statementId),
            statementId: _statementId,
            cost: _cost,
            requester: msg.sender,
            blockNumber: block.number
        });
        uint i = 0;
        while (i < requests[_statementId].length && requests[_statementId][i].cost > _cost) {
            i++;
        }
        requests[_statementId].push(request);
        for (uint j = requests[_statementId].length - 1; j > i; j--) {
            requests[_statementId][j] = requests[_statementId][j - 1];
        }
        requests[_statementId][i] = request;
    }

    function submitProposal(uint _statementId, uint _cost) public statementIdSupported(_statementId) {
        Proposal memory proposal = Proposal({
            id: _generateUniqueId(_statementId),
            cost: _cost,
            statementId: _statementId,
            proposer: msg.sender
        });
        uint i = 0;
        while (i < proposals[_statementId].length && proposals[_statementId][i].cost < _cost) {
            i++;
        }
        proposals[_statementId].push(proposal);
        for (uint j = proposals[_statementId].length - 1; j > i; j--) {
            proposals[_statementId][j] = proposals[_statementId][j - 1];
        }
        proposals[_statementId][i] = proposal;
    }

    function submitProof(uint index) public {
        require(index < orderMatches.length, "Invalid match index");
        OrderMatch storage matchedOrder = orderMatches[index];
        require(
            msg.sender == matchedOrder.proposer || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized to submit proof"
        );
        matchedOrder.proofed = true;
    }

    function matchOrders(uint statementId) public onlyRole(ADMIN_ROLE) {
        uint requestIndex = 0;
        uint proposalIndex = 0;

        while (requestIndex < requests[statementId].length && proposalIndex < proposals[statementId].length) {
            Request storage currentRequest = requests[statementId][requestIndex];
            Proposal storage currentProposal = proposals[statementId][proposalIndex];

            if (currentRequest.cost >= currentProposal.cost) {
                _addMatch(currentRequest, currentProposal);

                _removeRequest(statementId, requestIndex);
                _removeProposal(statementId, proposalIndex);
            } else {
                break;
            }
        }
    }

    function approveProofAndRemoveMatch(uint matchIndex) public {
        require(matchIndex < orderMatches.length, "Invalid match index");
        OrderMatch storage matchedOrder = orderMatches[matchIndex];
        require(
            hasRole(ADMIN_ROLE, msg.sender) || msg.sender == matchedOrder.requester,
            "Caller is not authorized"
        );
        matchedOrder.proofed = true;
        _removeMatch(matchIndex);
    }

    function _removeMatch(uint index) internal {
        require(index < orderMatches.length, "Index out of bounds");
        orderMatches[index] = orderMatches[orderMatches.length - 1];
        orderMatches.pop();
    }

    function _addMatch(
        Request memory _request,
        Proposal memory _proposal
    ) internal {
        orderMatches.push(OrderMatch({
            requestId: _request.id,
            proposalId: _proposal.id,
            statementId: _request.statementId,
            orderCost: _proposal.cost,
            requestCost: _request.cost,
            requester: _request.requester,
            proposer: _proposal.proposer,
            requestBlockNumber: _request.blockNumber,
            matchBlockNumber: block.number,
            proofed: false
        }));
        uint matchIndex = orderMatches.length - 1;
        pendingRequests[_request.requester].push(matchIndex);
        pendingProposals[_proposal.proposer].push(matchIndex);
    }

    function _generateUniqueId(uint _statementId) internal view returns (uint) {
        return uint(keccak256(abi.encodePacked(_statementId, msg.sender, block.timestamp, block.number)));
    }

    function _removeRequest(uint statementId, uint index) internal {
        for (uint i = index; i < requests[statementId].length - 1; i++) {
            requests[statementId][i] = requests[statementId][i + 1];
        }
        requests[statementId].pop();
    }

    function _removeProposal(uint statementId, uint index) internal {
        for (uint i = index; i < proposals[statementId].length - 1; i++) {
            proposals[statementId][i] = proposals[statementId][i + 1];
        }
        proposals[statementId].pop();
    }

}