import { connect } from 'react-redux';
import PollButton from '../components/poll_button';
import { addPoll, removePoll } from '../../../actions/compose';

const mapStateToProps = state => ({
  unavailable: false,
  active: state.getIn(['compose', 'poll']) !== null,
});

const mapDispatchToProps = dispatch => ({

  onClick () {
    dispatch((_, getState) => {
      if (getState().getIn(['compose', 'poll'])) {
        dispatch(removePoll());
      } else {
        dispatch(addPoll());
      }
    });
  },

});

export default connect(mapStateToProps, mapDispatchToProps)(PollButton);
