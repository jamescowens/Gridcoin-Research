// Copyright (c) 2014-2022 The Gridcoin developers
// Distributed under the MIT/X11 software license, see the accompanying
// file COPYING or https://opensource.org/licenses/mit-license.php.

#include "gridcoin/support/xml.h"
#include "gridcoin/voting/vote.h"

using namespace GRC;

// -----------------------------------------------------------------------------
// Class: Vote
// -----------------------------------------------------------------------------

Vote::Vote(
    const uint32_t version,
    const uint256 poll_txid,
    std::vector<uint8_t> responses,
    VoteWeightClaim claim)
    : m_version(version)
    , m_poll_txid(poll_txid)
    , m_responses(std::move(responses))
    , m_claim(std::move(claim))
{
}

bool Vote::ResponseExists(const uint8_t offset) const
{
    return std::any_of(
        m_responses.begin(),
        m_responses.end(),
        [&](const uint8_t response) { return response == offset; });
}

// -----------------------------------------------------------------------------
// Class: LegacyVote
// -----------------------------------------------------------------------------

LegacyVote::LegacyVote(
    std::string key,
    MiningId mining_id,
    double amount,
    double magnitude,
    std::string responses)
    : m_key(std::move(key))
    , m_mining_id(mining_id)
    , m_amount(amount)
    , m_magnitude(magnitude)
    , m_responses(std::move(responses))
{
}

LegacyVote LegacyVote::Parse(const std::string& key, const std::string& value)
{
    const auto parse_double = [](const std::string& value, const double places) {
        const double scale = std::pow(10, places);

        double parsed_value = 0.0;

        if (!ParseDouble(value, &parsed_value)) {
            LogPrintf("WARN: %s: Error parsing legacy vote with value = %s",
                      __func__, value);
        }

        return std::nearbyint(parsed_value * scale) / scale;
    };

    return LegacyVote(
        key,
        MiningId::Parse(ExtractXML(value, "<CPID>", "</CPID>")),
        parse_double(ExtractXML(value, "<BALANCE>", "</BALANCE>"), 0),
        parse_double(ExtractXML(value, "<MAGNITUDE>", "</MAGNITUDE>"), 2),
        ExtractXML(value, "<ANSWER>", "</ANSWER>"));
}

std::vector<std::pair<uint8_t, uint64_t>>
LegacyVote::ParseResponses(const std::map<std::string, uint8_t>& choice_map) const
{
    std::vector<std::string> answers = split(m_responses, ";");
    std::vector<std::pair<uint8_t, uint64_t>> responses;

    for (auto& answer : answers) {
        answer = ToLower(answer);

        auto iter = choice_map.find(answer);

        if (iter != choice_map.end()) {
            responses.emplace_back(iter->second, 0);
        }
    }

    return responses;
}
