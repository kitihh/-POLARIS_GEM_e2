#!/usr/bin/env python3

import sys
import unittest
import rospy
import rostest
from std_msgs.msg import Float32
from geometry_msgs.msg import PoseStamped
from gazebo_msgs.msg import ModelState
from gazebo_msgs.srv import GetModelState

class TestPurePursuitCTError(unittest.TestCase):
    def setUp(self):
        rospy.init_node('test_ct_error')
        self.ct_errors = []
        self.test_duration = rospy.Duration(10.0)
        self.max_ct_error = 1.0
        
        rospy.Subscriber('/gem/ct_error', Float32, self.ct_error_callback)
        
        rospy.wait_for_service('/gazebo/get_model_state')
        self.get_model_state = rospy.ServiceProxy('/gazebo/get_model_state', GetModelState)

    def ct_error_callback(self, msg):
        self.ct_errors.append(msg.data)

    def test_ct_error_requirement(self):
        start_time = rospy.Time.now()
        while (rospy.Time.now() - start_time) < self.test_duration:
            rospy.sleep(0.1)

        self.assertGreater(len(self.ct_errors), 0, "Cross-Track Error messages missing")

        max_error = max(abs(error) for error in self.ct_errors)
        self.assertLessEqual(max_error, self.max_ct_error, 
            f"Maximum Cross-Track Error ({max_error}m) exceeded {self.max_ct_error}m")

if __name__ == '__main__':
    rostest.rosrun('gem_pure_pursuit_sim', 'test_ct_error', TestPurePursuitCTError)