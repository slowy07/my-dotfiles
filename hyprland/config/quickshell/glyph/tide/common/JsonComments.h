#pragma once

#include <QByteArray>

namespace JsonComments {

// Replace comment bytes with spaces, preserving UTF-8 strings and error offsets.
inline QByteArray strip(const QByteArray &input){
    QByteArray output;
    output.reserve(input.size());

    enum class State {
        Normal,
        String,
        LineComment,
        BlockComment,
    };

    State state = State::Normal;
    bool escaped = false;

    for (qsizetype i = 0; i < input.size(); ++i) {
        const char ch = input.at(i);
        const char next = i + 1 < input.size() ? input.at(i + 1) : '\0';

        switch (state) {
        case State::Normal:
            if (ch == '"') {
                output.append(ch);
                state = State::String;
            } else if (ch == '/' && next == '/') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::LineComment;
            } else if (ch == '/' && next == '*') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::BlockComment;
            } else {
                output.append(ch);
            }
            break;
        case State::String:
            output.append(ch);
            if (escaped) {
                escaped = false;
            } else if (ch == '\\') {
                escaped = true;
            } else if (ch == '"') {
                state = State::Normal;
            }
            break;
        case State::LineComment:
            if (ch == '\n' || ch == '\r') {
                output.append(ch);
                state = State::Normal;
            } else {
                output.append(' ');
            }
            break;
        case State::BlockComment:
            if (ch == '*' && next == '/') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::Normal;
            } else if (ch == '\n' || ch == '\r') {
                output.append(ch);
            } else {
                output.append(' ');
            }
            break;
        }
    }

    return output;
}

} // namespace JsonComments
