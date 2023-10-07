// SPDX-License-Identifier: MIT
/*
* Batch: ACSE IITM August 2022
* Project: Problem Statement 3 - Blockchain based Ticket Management
* Developers: 
    Mohan Sami (Group Lead)
    Anuradha Kapoor
    Reema Chhetri
    Sachin Ghewde (SG) - <sachingg@hotmail.com>
* Description:
    ACSE IITM Capstone Project – Blockchain based Ticket Management - Eagle Airlines
    Goals
    •	Develop a Private Ethereum Blockchain implementation, using geth nodes running directly on a single AWS EC2 (Ubuntu) server.
    •	Use Clique PoA (Proof of Authority) as the consensus protocol.
    •	Develop a base Flight ticket management contract in Solidity to allow.
    •	Use MetaMask as the wallet for Customers.
    •	Demonstrate contract behavior via Remix connected to the private blockchain.
*/

pragma solidity ^0.8.17;
// For console.log
import "hardhat/console.sol";
import "./EagleLib.sol";
import "./EagleAirline.sol";

///////////////////////////////////////////////////////////////////////////////////////////////
/*
* Sample Airport Codes - Domestic (India)
    BOM (Mumbai), DEL (Delhi), BLR (Bengaluru), MAA (Chennai), CCU (Kolkata)
* Sample Airport Codes - International 
    NYC (New York, USA), AMS (Amsterdam, Netherlands), TYO (Tokyo, Japan), SYD (Sydney, Australia)
* Datetime <> Epoch Timestamp convertor
    https://www.epochconverter.com/
*/
///////////////////////////////////////////////////////////////////////////////////////////////
// Eagle Airline contract - keeps track of the Arilines & flight details & ticket buyer (customer) details across multiple flights.
contract EagleTicket {
    //
    //EagleLib private EagleLib;
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // DATA MEMBERS
    // FlightStatus - enumerates various flight states
    uint private constant _TIME_UNITS = 1 minutes; // 1 hours; i.e. (60 * 60) seconds // FOR TESTING use 1 minutes i.e. (60) seconds
    uint8 private constant FLIGHT_SCHEDULED = 0;
    uint8 private constant FLIGHT_ON_TIME = 1;
    uint8 private constant FLIGHT_DELAYED = 2;
    uint8 private constant FLIGHT_BOARDING = 3;
    uint8 private constant FLIGHT_IN_AIR = 4;
    uint8 private constant FLIGHT_LANDED = 5;
    uint8 private constant FLIGHT_CANCELLED = 6;
    uint8 private constant FLIGHT_DOES_NOT_EXIST = 7;
    // TicketStatus - enumerates various ticket states
    uint8 private constant TICKET_VOID = 0;
    uint8 private constant TICKET_RESERVED = 1;
    uint8 private constant TICKET_CONFIRMED = 2;
    uint8 private constant TICKET_CLOSED = 3;
    uint8 private constant TICKET_CANCELLATION_IN_PROGRESS = 4;
    uint8 private constant TICKET_CANCELLED = 5;
    uint8 private constant TICKET_DOES_NOT_EXIST = 6;
    // PaymentStatus - enumerates the payment states
    uint8 private constant PAYMENT_PENDING = 0;
    uint8 private constant PAYMENT_COLLECTED = 1;
    uint8 private constant PAYMENT_REFUNDED = 2; // Settled by full refund to customer
    uint8 private constant PAYMENT_SPLIT = 3; // Settled by part refund to customer + part payment to airline
    uint8 private constant PAYMENT_PAID = 4; // Settled by full payment to airline
    //
    address private _ticketContract; // this, contract address
    uint private _ticketNumber; // "1234567890123" unique 13-digit number    
    address private _eagleAirContract; // parent EagleAirline contract address
    //address private _tokenARMS; // tokenARMS address
    EagleAirline private _eagleAirline; // parent EagleAirline object (_eagleAirContract)
    address payable private _operatorAddress; // parent, EagleAirline Operator (Domestice, International) address
    address payable private _buyerAddress; // buyer who bought this ticket - customer address
    uint8 private _ticketStatus; // last known status of ticket
    uint8 private _paymentStatus; // last known status of payment
    uint private _ticketTimeStamp; // time when this was created
    uint private _ticketStatusTimeStamp; // last ticket status update date time
    uint private _paymentStatusTimeStamp; // last payment status update date time
    bool private _refundClaimed;
    // additional TicketInfo
    struct TicketInfo {
        uint flightNumber; // flight
        //string seatCategory; // "Economy"
        string seatNumber; // "A24"
        uint ticketAmount;
        uint collectedAmount;
        uint refundAmount; // amount refunded to Customer, if any 
        uint paidAmount; // amount paid to Airline, if any
        uint collectedTimeStamp;
        uint settledTimeStamp;
        uint schDepartureTimeStamp;
    }
    TicketInfo private _ticketInfo;
    //


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    constructor (
        //address tokenARMS,
        address eagleAir,
        address operatorAddress,
        address buyerAddress,
        uint ticketNumber,
        uint flightNumber,
        string memory seatNumber,
        uint ticketAmount,
        uint schDepartureTimeStamp
    ) {
        require(operatorAddress != address(0), "Error: Invalid Airline address");
        require(buyerAddress != address(0), "Error: Invalide Customer address");
        require(ticketNumber > 0, "Error: Invalid Ticket #");
        require(flightNumber > 0, "Error: Invalid Flight #");
        require(ticketAmount > 0, "Error: Invalid Ticket Amount");

        _ticketContract = address(this);
        _eagleAirContract = address(eagleAir); // Only the parent can create this contract
        _eagleAirline = EagleAirline(_eagleAirContract);
        _operatorAddress = payable(operatorAddress);
        _buyerAddress = payable(buyerAddress);
        _ticketNumber = ticketNumber;
        // additional info
        _ticketStatus = TICKET_RESERVED;
        _paymentStatus = PAYMENT_PENDING;
        _ticketTimeStamp = block.timestamp;
        _refundClaimed = false;
        _ticketInfo = TicketInfo({
            flightNumber: flightNumber,
            seatNumber: seatNumber,
            ticketAmount: ticketAmount,
            collectedAmount: 0,
            refundAmount: 0,
            paidAmount: 0,
            collectedTimeStamp: 0,
            settledTimeStamp: 0,
            schDepartureTimeStamp: schDepartureTimeStamp
        });
        //
        emit ContractCreated("Ticket Contract", address(this));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    // EVENTS
    event ContractCreated(string contractName, address indexed contractAddress);
    //event TicketReserved (uint flightNumber, uint ticketNumber, uint transferredAmount, string message);
    event TicketConfirmed(uint flightNumber, uint ticketNumber, uint transferredAmount, uint collectedAmount, string message);
    event TicketCancelled(uint ticketNumber, string message);
    event TicketClosed(uint ticketNumber, string message);
    event TicketRefundClaimed(uint ticketNumber, string message);
    event ViewTicket(uint ticketNumber, uint flightNumber, string seatNumber, string ticketStatus, string paymentStatus, uint collectedAmount);
    //event TicketCancelled (address indexed airline, address indexed customer, uint flightNumber, uint ticketNumber, string message);
    event ErrorMessage(string errorMessage);
    event InfoMessage(string infoMessage);
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    modifier OnlyAirlineContract() {
        require(msg.sender == address(_eagleAirContract), "Only Airline Contract allowed");
        _;
    }
    //
    modifier OnlyBuyer() {
         require(msg.sender == address(_buyerAddress), "Only Ticket Buyer allowed");
        _;
    }
    //
    modifier OnlyBuyerOrOpertor() {
        require(
                (
                    msg.sender == address(_operatorAddress)
                    || msg.sender == address(_buyerAddress)
                ),
                "Only Airline Flight Operator / Ticket Buyer allowed"
            );
        _;
    }
    /*
    modifier CheckTicketNumber(uint ticketNumber) {
        // Valid ticket numbers are 13 digits
        require(ticketNumber > 1000000000000 && ticketNumber < 10000000000000, "Invalid Ticket Number provided");
        _;
    }
    */
    
    /*
    * VIEW TICKET INFO - Allows customers to get view ticket information
    */
    function viewTicketInfo() external OnlyBuyerOrOpertor {
        string memory ticketStatus = _getTicketStatusText(_ticketStatus);
        string memory paymentStatus = _getPaymentStatusText(_paymentStatus);
        emit ViewTicket (
            _ticketNumber,
            _ticketInfo.flightNumber, 
            _ticketInfo.seatNumber, 
            ticketStatus,
            paymentStatus,
            _ticketInfo.collectedAmount
        );
    }

    // !! PAYABLE !!
    /*
    * COMPLETE PURCHASE - Allows buyers to pay & complete payment for the ticket
    */
    function confirmTicket () external payable OnlyBuyer returns (bool success) {
        success = false;
        uint ticketPrice =  _ticketInfo.ticketAmount;
        //console.log(msg.value, ticketPrice);
        require(msg.value >= ticketPrice, "Insufficient Amount provided to complete purchase");
        // Confirm with Airline
        success = _eagleAirline.confirmTicket(_ticketContract, msg.sender);
        require(success, "ERR: Ticket purchase failed");
        // Transfer funds, if any back to customer (sender)
        uint256 transferAmount = (msg.value - ticketPrice);
        if (transferAmount > 0) {
            //payable(msg.sender).transfer(transferAmount);
            (bool callSuccess, ) = payable(msg.sender).call{value: transferAmount}("");
            require(callSuccess, "ERR: Ticket purchase failed");
            //
            _ticketStatus = TICKET_CONFIRMED;
            _paymentStatus = PAYMENT_COLLECTED;
            success = true;
        }    
        //
        _ticketInfo.collectedAmount = ticketPrice;
        _ticketStatus = TICKET_CONFIRMED;
        _ticketStatusTimeStamp = block.timestamp;
        _paymentStatus = PAYMENT_COLLECTED;
        _paymentStatusTimeStamp = block.timestamp;
        emit TicketConfirmed(_ticketInfo.flightNumber, _ticketNumber, transferAmount, ticketPrice, "! Ticket Payment Confirmed !");
    }

    /*
    * SELECT SEAT - Allows buyers to select/change seats
    */
    function selectSeat (string memory seatNumber) external OnlyBuyer returns (bool success) {
        success = _eagleAirline.selectSeat(_ticketContract, seatNumber);
        if(success)
            _ticketInfo.seatNumber = seatNumber; 
    }
    
    
    // !! PAYABLE !!
    function cancelTicket () external payable OnlyBuyer returns (bool success, string memory message) {
        /*
        * Cancellation by Customer rules
        * Rule: Based on DIFFERENCE of (Scheduled Departure Datetime – Cancellation Datetime)
        *   RESERVED (Unconfirmed) tickets can be cancelled (voided) anytime without penalty. They will automatically be VOID after Flight take-off.
        *   If >= 24 hours	100%
        *   If >= 4 hours and < 24 hours	80%
        *   If >= 2 hour and < 4 hours	40%
        *   If < 2 hour	NOT ALLOWED (revert transaction)
        */
        // Check ticket status
        uint currTime = block.timestamp;
        if (_ticketStatus == TICKET_RESERVED) {
            (success, message) = _eagleAirline.voidTicket(_ticketContract);
            _ticketStatus = TICKET_VOID;
            _ticketStatusTimeStamp = currTime;
            emit TicketCancelled(_ticketNumber, message);
            //selfdestruct(_buyerAddress);
        } else if (_ticketStatus == TICKET_CANCELLATION_IN_PROGRESS) {
            revert ("Err: Prev CANCELLATION IN PROGRESS");
        } else if (_ticketStatus == TICKET_CANCELLED) {
            revert ("Err: Ticket already CANCELLED");
        }
        if (!_refundClaimed) {
            uint8 flightStatus = _eagleAirline.getflightStatus(_ticketInfo.flightNumber);
            require(
                flightStatus >= FLIGHT_SCHEDULED && flightStatus <= FLIGHT_DELAYED,
                "ERR: Ticket cannot be cancelled. Check Flight status"
            );
            uint timeBasisSeconds = (_ticketInfo.schDepartureTimeStamp > currTime) ? _ticketInfo.schDepartureTimeStamp - currTime : 0;
            // Calculate refund
            uint8 percentRefund = _getPercentRefund(timeBasisSeconds, flightStatus, true);
            require(percentRefund > 0, "ERR: Ticket cancellation window closed");
            _ticketStatus = TICKET_CANCELLATION_IN_PROGRESS;
            _ticketStatusTimeStamp = currTime;
            //
            uint256 refundAmount;
            uint256 payAmount;
            // Transfer funds
            bool refundCallSuccess;
            bool payCallSuccess;
            // Balance has to be >= the collected payment
            uint balanceAmount = address(this).balance;
            if (balanceAmount >= _ticketInfo.collectedAmount) {     
                refundAmount = balanceAmount * (percentRefund / 100.00);
                payAmount = balanceAmount - refundAmount; // balance
                // Refund the Buyer first
                if (refundAmount > 0) {
                    (refundCallSuccess, ) = payable(_buyerAddress).call{value: refundAmount}("");
                    require(refundCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
                }
                // Send the remaining balance to Airline
                if (payAmount > 0) {
                    (payCallSuccess, ) = payable(_operatorAddress).call{value: payAmount}("");
                    require(payCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
                }
            } else {
                message = "ERR: Insufficient funds. Contact customer support.";
                revert (message);
            }
            require(refundCallSuccess || payCallSuccess, "ERR: Ticket cancellation failed. Contact customer support.");
            _settlePayment(refundAmount, payAmount);
        }
        //
        _ticketStatus = TICKET_CANCELLED;
        _ticketStatusTimeStamp = currTime;
        _ticketInfo.seatNumber = "NA";
        // Confirm with Airline
        (success, message) = _eagleAirline.cancelTicket(_ticketContract);
        require(success, message); 
        success = true;
        message = string.concat("INFO: Ticket Cancelled. Ticket # ", EagleLib.uintToString(_ticketNumber));
        emit TicketCancelled (_ticketNumber, message);
    }

    // !! PAYABLE !!
    function closeTicket (uint8 flightStatus, uint schDepartTS, uint actDepartTS, uint preflightStsTS) external payable OnlyAirlineContract returns (bool success) {
        // Check ticket status
        uint currTime = block.timestamp;
        require(_ticketStatus >= TICKET_RESERVED && _ticketStatus <= TICKET_CONFIRMED, "ERR: Cannot close due to Ticket status (VOID/CLOSED/CANCELLED)");
        require(flightStatus == FLIGHT_LANDED || flightStatus == FLIGHT_CANCELLED, "ERR: Invalid Flight status");
        if (_ticketStatus == TICKET_RESERVED) {
            _ticketStatus = TICKET_VOID;
            _ticketStatusTimeStamp = currTime;
            emit TicketClosed(_ticketNumber,  "VOID Ticket");
        }
        //
        uint balanceAmount = address(this).balance;
        if (
            (!_refundClaimed && _paymentStatus == PAYMENT_COLLECTED) 
            || balanceAmount > 0
        ) {
            // Calculate Delay time if any
            uint delaytime = _calculateDelaytime(flightStatus, schDepartTS, actDepartTS, preflightStsTS);
            // Transfer funds
            uint256 refundAmount;
            uint256 payAmount;
            bool refundCallSuccess;
            bool payCallSuccess;
            // Balance has to be >= the collected payment
            if (balanceAmount > _ticketInfo.collectedAmount) {  
                uint8 percentRefund = _getPercentRefund(delaytime, flightStatus, false);
                refundAmount = balanceAmount * (percentRefund/100.00);
                payAmount = balanceAmount - refundAmount;
                //refundAmount = (flightStatus == FLIGHT_CANCELLED) ? _ticketInfo.collectedAmount : 0;
                //payAmount = (flightStatus == FLIGHT_LANDED) ? _ticketInfo.collectedAmount : 0;
                // Refund the Buyer
                if (refundAmount > 0) {
                    (refundCallSuccess, ) = payable(_buyerAddress).call{value: refundAmount}("");
                    require(refundCallSuccess, "ERR: Refund failed");
                }
                // Send balance to Airline
                if (payAmount > 0) {
                    (payCallSuccess, ) = payable(_operatorAddress).call{value: payAmount}("");
                    require(payCallSuccess, "ERR: Payment failed");
                }
            } else {
                revert ("ERR: Insufficient funds to close ticket");
            }
            require(refundCallSuccess || payCallSuccess, "ERR: Close Ticket failed");
            // Update payment info
            _paymentStatusTimeStamp = currTime;
            if (refundAmount > 0 && payAmount > 0)
                _paymentStatus = PAYMENT_SPLIT;
            else if (refundAmount > 0 && payAmount == 0)
                _paymentStatus = PAYMENT_REFUNDED;
            else if (refundAmount == 0 && payAmount > 0)
                _paymentStatus = PAYMENT_PAID;
            _ticketInfo.refundAmount = refundAmount;
            _ticketInfo.paidAmount = payAmount;
        }
        //
        _ticketStatus = TICKET_CLOSED;
        _ticketStatusTimeStamp = currTime;
        _ticketInfo.seatNumber = "NA";
        success = true;
        emit TicketClosed (_ticketNumber, "INFO: Ticket Closed");
    }

    // !! PAYABLE !!
    function claimRefund () external payable OnlyBuyer returns (bool success) {
        /*
        * Delayed by Airline – Penalty Rules
        * Rule: 
        * If Ticket Status != CLOSED/CANCELLED
        * Customer can claim a refund only once
        * Determine Delay Time
        *  If Flight Status = CANCELLED
        *       Percent Refund = 100% refund
        *  Else If Flight Status < CANCELLED
        *       AND the Status was not updated by the Airline within the time window = (From: Scheduled Departure - 24 hours) to (To: Scheduled Departure) 
        *           Percent Refund = 100% refund
        *       (If Actual Departure Datetime is not updated within 24 hours from Scheduled Departure Datetime	100%)
        *  Else calculate actual Delay time:
        *       If flight STATUS = LANDED/IN-AIR
        *            Delay time = (Actual Departure - Scehduled Departure)
        *       Else
        *           Delay time = (Current Time - Scehduled Departure) 
        *       Percent Refund, Based on Delay Time
        *           If >= 2 hours and < 10 hours	10%
        *           If >= 10 hours and < 24 hours	40%
        *           If >= 24 hours	100%
        */
        require(!_refundClaimed, "ERR: Refund claim already processed");
        // Check ticket status
        if (_ticketStatus <= TICKET_CANCELLED) 
            revert ("ERR: Ticket already Cancelled");
        else if (_ticketStatus == TICKET_CANCELLATION_IN_PROGRESS)
            revert ("ERR: Ticket CANCELLATION is in progress");
        //
        require(_paymentStatus == PAYMENT_COLLECTED, "ERR: Refund not applicable"); // payment was never collected or has already be refunded/paid
        uint currTime = block.timestamp;
        (uint8 flightStatus, uint schDeparturetTS,, uint newDeparturetTS,, uint preflightStsTS) = _eagleAirline.getflightStatusTime(_ticketInfo.flightNumber);
        require (currTime - schDeparturetTS >= (24 * _TIME_UNITS), "ERR: Ticket not elligible for claim");
        //
        // Calculate Refund percent based on Delay Time
        uint timeBasisSeconds = _calculateDelaytime(flightStatus, schDeparturetTS, newDeparturetTS, preflightStsTS);
        uint8 percentRefund = _getPercentRefund(timeBasisSeconds, flightStatus, false);
        require(percentRefund > 0, "ERR: Claim is not valid");
        // Calculate amount based on percent and if any refunds were previously paid
        uint256 refundAmount = _ticketInfo.collectedAmount * (percentRefund / 100);
        uint256 payAmount = _ticketInfo.collectedAmount - refundAmount; // balance
        bool refundCallSuccess; bool payCallSuccess;
        // Balance has to be >= the collected payment
        uint balanceAmount = address(this).balance;
        //if (ARMSToken(_tokenARMS).balanceOf(address(this)) > _ticketInfo.collectedAmount) {  
        if (balanceAmount > _ticketInfo.collectedAmount) {   
            refundAmount = _ticketInfo.collectedAmount * (percentRefund / 100); 
            payAmount = _ticketInfo.collectedAmount - refundAmount; // balance 
            // Refund the Buyer
            if (refundAmount > 0) {
                //refundCallSuccess = ARMSToken(_tokenARMS).transfer(payable(_buyerAddress), refundAmount);
                (refundCallSuccess, ) = payable(_buyerAddress).call{value: refundAmount}("");
                require(refundCallSuccess, "ERR: Refund call failed. Contact customer support.");
            }
            // Send balance to Airline
            if (payAmount > 0) {
                //payCallSuccess = ARMSToken(_tokenARMS).transfer(payable(_operatorAddress), penaltyAmount);
                (payCallSuccess, ) = payable(_operatorAddress).call{value: payAmount}("");
                require(payCallSuccess, "ERR: Payment failed. Contact customer support.");
            }
        } else {
            revert ("ERR: Insufficient funds to settle claim. Contact customer support.");
        }
        require(refundCallSuccess || payCallSuccess, "ERR: Refund claim failed. Contact customer support.");
        // Update payment info
        _refundClaimed = true;
        _paymentStatusTimeStamp = currTime;
        if (refundAmount > 0 && payAmount > 0)
            _paymentStatus = PAYMENT_SPLIT;
        else if (refundAmount > 0 && payAmount == 0)
            _paymentStatus = PAYMENT_REFUNDED;
        else if (refundAmount == 0 && payAmount > 0)
            _paymentStatus = PAYMENT_PAID;
        //
        _ticketInfo.refundAmount = refundAmount;
        _ticketInfo.paidAmount = payAmount;
        //
        _ticketStatus = TICKET_CLOSED;
        _ticketStatusTimeStamp = block.timestamp;
        _paymentStatusTimeStamp = _ticketStatusTimeStamp;
        success = true;
        emit TicketRefundClaimed(_ticketNumber, "INFO: Ticket Refund Claimed");
    }


    ///////////////////////////////////////////////////////////////////////////////////////////////
    // private functions
    function _getTicketStatusText (uint status) private pure returns (string memory) {
        if (status == TICKET_RESERVED) {
            return "RESERVED";
        } else if (status == TICKET_CONFIRMED) {
            return "CONFIRMED";
        } else if (status == TICKET_CANCELLATION_IN_PROGRESS) {
            return "CANCELLATION-IN-PROGRESS";
        } else if (status == TICKET_CANCELLED) {
            return "CANCELLED";
        } else {
            return "UNKNOWN";
        }
    }

    // Helper function to get ticket status text
    function _getPaymentStatusText (uint status) private pure returns (string memory) {
        if (status == PAYMENT_PENDING) {
            return "PENDING";
        } else if (status == PAYMENT_COLLECTED) {
            return "COLLECTED";
        } else if (status == PAYMENT_REFUNDED) {
            return "REFUNDED";
        } else if (status == PAYMENT_SPLIT) {
            return "SPLIT";
        } else if (status == PAYMENT_PAID) {
            return "PAID";
        } else {
            return "UNKNOWN";
        }
    }   

    function _calculateDelaytime(uint8 flightStatus, uint schDeparturetTS, uint actDepartureTS, uint preflightStsTS) private view returns (uint) {
         if (flightStatus == FLIGHT_CANCELLED) {
            return (24 * _TIME_UNITS); // Note: Flight cancellation should have already cancelled the ticket and refunded 100%
            //percentRefund = 100; // 100 %
        } else if (flightStatus < FLIGHT_CANCELLED  
            && schDeparturetTS - preflightStsTS > (24 * _TIME_UNITS)
        ) {
            // Check if the Airline delayed to update status within 24 hours of the schedueld departure time 
           return (24 * _TIME_UNITS);
           //percentRefund = 100; // 100 %
        }
         else if (
            flightStatus <  FLIGHT_CANCELLED
        ) {
            // Check if the flight is/was actually delayed
            // If light has landed, newDeparturetTS = actual departure datetime
            //  else use currTime
            return (((flightStatus ==  FLIGHT_LANDED || flightStatus ==  FLIGHT_IN_AIR)? actDepartureTS : block.timestamp) - schDeparturetTS);
            //percentRefund = _getPercentRefund(delayTime, true);
        }
        return 0;
    }

    function _getPercentRefund(uint timeBasisSeconds, uint8 flightStatus, bool isTicketCancellation) private pure returns (uint8) {
        console.log("timeBasisSeconds = ", timeBasisSeconds);
        console.log("flightStatus = ", flightStatus);
        console.log("isTicketCancellation = ", isTicketCancellation);
        if (flightStatus == FLIGHT_CANCELLED)
            return 100;
        //
        if (timeBasisSeconds >= (24 * _TIME_UNITS))
            return (isTicketCancellation) ? 100 : 100;
        else if (timeBasisSeconds >= (10 * _TIME_UNITS) && timeBasisSeconds < (24 * _TIME_UNITS))
            return (isTicketCancellation) ? 80 : 40;
        else if (timeBasisSeconds >= (2 * _TIME_UNITS) && timeBasisSeconds < (10 * _TIME_UNITS))
            return (isTicketCancellation) ? 40 : 10;
        else
            return 0;
    }

    function _settlePayment(uint refundedAmount, uint paidAmount) private returns (bool) {
        _paymentStatusTimeStamp = block.timestamp;
        if (refundedAmount > 0 && paidAmount > 0) {
            _paymentStatus = PAYMENT_SPLIT;
        } else if (refundedAmount > 0 && paidAmount == 0) {
            _paymentStatus = PAYMENT_REFUNDED;
        } else if (refundedAmount == 0 && paidAmount > 0) {
            _paymentStatus = PAYMENT_PAID;
        }
        _ticketInfo.refundAmount = refundedAmount;
        _ticketInfo.paidAmount = paidAmount;
        return true;
    }
}