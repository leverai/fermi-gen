/// State of the question pane (button area)
enum QuestionPaneState {
  started, // Active, can submit
  locked, // Submitted/Waiting, cannot submit
  finished, // Revealed, can go next
}
